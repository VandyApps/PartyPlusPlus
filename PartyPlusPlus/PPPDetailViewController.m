//
//  PPPDetailViewController.m
//  PartyPlusPlus
//
//  Created by Scott Andrus on 10/13/12.
//  Copyright (c) 2012 Tapatory. All rights reserved.
//

#import "PPPDetailViewController.h"
#import "SAViewManipulator.h"
#import "UIView+Frame.h"
#import "PPPPost.h"

#define WALL_PHOTO_PARAMS @"source"
#define ATTENDING_PARAMS @"picture"
#define FEED_PARAMS @"message,from"

@interface PPPDetailViewController ()

@end

@implementation PPPDetailViewController
@synthesize messagePosts;
@synthesize imagePosts;
@synthesize attendingScrollView;
@synthesize attendingFriendsUrls;
@synthesize feedScrollView;
@synthesize wallPhotoImageView;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self didPullEventPhotoURLsWithCallBack:^{
        [self setupFeedScrollView];
    }];
    [self didPullAttendingPhotoURLsWithCallBack:^{
        [self setupAttendingScrollView];
    }];

    // Round the navigation bar
    [SAViewManipulator roundNavigationBar:self.navigationController.navigationBar];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - ScrollView Methods
- (void)setupAttendingScrollView {
    
    // Create a main event view pointer
    UIImageView *view;
    
    self.attendingScrollView.contentSize = CGSizeMake(self.thumbnailImageView.width * self.attendingFriendsUrls.count, self.thumbnailImageView.height);

    
    // Create 10 events
    for (size_t i = 0; i < self.attendingFriendsUrls.count; ++i) {
        
        // Allocate and initialize the event
        view = [[UIImageView alloc] initWithFrame:self.thumbnailImageView.frame];
        
        view.left = (self.thumbnailImageView.width + 5) * i;
        
        // Set the labels
        [self downloadPhoto:[self.attendingFriendsUrls objectAtIndex:i] forImageView:view];

        
        // Add it to the subview
        [self.attendingScrollView addSubview:view];
        
    }
    
}

#pragma mark - ScrollView Methods
- (void)setupFeedScrollView {
    
    // Create a main event view pointer
    UIImageView *view;
    
//    self.feedScrollView.contentSize = CGSizeMake(self.wallPhotoImageView.width, self.wallPhotoImageView.height * self.posts.count);
    
    
//    // Create 10 events
//    for (size_t i = 0; i < self.posts.count; ++i) {
//        
//        // Allocate and initialize the event
//        view = [[UIImageView alloc] initWithFrame:self.wallPhotoImageView.frame];
//        
//        view.top = (self.wallPhotoImageView.height + 10) * i;
//        
//        // Set the labels
////        view.image = [UIImage imageNamed:@"Thumbnail.png"];
//        PPPPost *post = [self.posts objectAtIndex:i];
//        [self downloadPhoto:post.imageURL forImageView:view];
//        
//        // Add it to the subview
//        [self.feedScrollView addSubview:view];
    
//    }
    
}

#pragma mark - Facebook API Calls
- (void)downloadPhoto:(NSString *)urlStr forImageView:(UIImageView*)imageView {
    if (!self.event.image) {
        // Download photo
        UIActivityIndicatorView *loading = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        [loading startAnimating];
//        [self addSubview:loading];
//        loading.center = self.center;
        
        dispatch_queue_t downloadQueue = dispatch_queue_create("image downloader", NULL);
        dispatch_async(downloadQueue, ^{
            
            // TODO: Add a different image for each location
            NSData *imgUrl;
            if (!urlStr) {
                imgUrl = [NSData dataWithContentsOfURL:[NSURL URLWithString:@"http://placekitten.com/g/480/480"]];
            } else {
                imgUrl = [NSData dataWithContentsOfURL:[NSURL URLWithString:urlStr]];
            }
            
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [imageView setImage:[UIImage imageWithData:imgUrl]];
                [loading stopAnimating];
                [loading removeFromSuperview];
            });
        });
        dispatch_release(downloadQueue);
    }
}

- (void)pullMessagePostsWithCallBack:(void (^)(void))callback; {
    
    FBRequestConnection *requester = [[FBRequestConnection alloc] init];
    NSString *graphPath = [NSString stringWithFormat:@"/%@/feed", self.event.eventId];
    FBRequest *request = [FBRequest requestWithGraphPath:graphPath parameters:FEED_PARAMS HTTPMethod:@"GET"];
    [requester addRequest:request completionHandler:^(FBRequestConnection *connection,
                                                      FBGraphObject *response,
                                                      NSError *error) {
        if (!error) {
            
            // Ok, so grab an event array
            NSArray *eventArrayFromGraphObject = [response objectForKey:@"data"];
            
            // temp event array to hold
            NSMutableArray *tempPostArray = [NSMutableArray array];
            for (id dict in eventArrayFromGraphObject) {
                if ([dict objectForKey:@"message"]) {
                    NSString *poster = [[dict objectForKey:@"from"] objectForKey:@"name"];
                    NSString *message = [dict objectForKey:@"message"];
                    NSString *dateString = [dict objectForKey:@"created_time"];
                    PPPPost *post = [[PPPPost alloc] initWithMessage:message andDateString:dateString andPoster:poster];
                    [tempPostArray addObject:post];
                }
                
            }
            
            // Create an immutable copy for the property
            self.messagePosts = [tempPostArray copy];
            callback();
        }
        
    }];
    
    [requester start];
    
}

- (void)didPullEventPhotoURLsWithCallBack:(void (^)(void))callback; {
    
    FBRequestConnection *requester = [[FBRequestConnection alloc] init];
    NSString *graphPath = [NSString stringWithFormat:@"/%@/photos", self.event.eventId];
    FBRequest *request = [FBRequest requestWithGraphPath:graphPath parameters:[NSDictionary dictionaryWithObject:WALL_PHOTO_PARAMS forKey:@"fields"] HTTPMethod:@"GET"];
    [requester addRequest:request completionHandler:^(FBRequestConnection *connection,
                                                      FBGraphObject *response,
                                                      NSError *error) {
        if (!error) {
            
            // Ok, so grab an event array
            NSArray *eventArrayFromGraphObject = [response objectForKey:@"data"];
            
            // temp event array to hold
            NSMutableArray *tempPostArray = [NSMutableArray array];
            for (id dict in eventArrayFromGraphObject) {
                NSString *photoURL = [dict objectForKey:@"source"];
                NSString *dateString = [dict objectForKey:@"created_time"];
                NSString *poster = [[dict objectForKey:@"from"] objectForKey:@"name"];
                PPPPost *post = [[PPPPost alloc] initWithImageUrl:photoURL andDateString:dateString andPoster:poster];
                [tempPostArray addObject:post];
            }
            
            // Create an immutable copy for the property
            self.imagePosts = [tempPostArray copy];
            callback();
            
        }
        
    }];
    
    [requester start];

}

- (void)didPullAttendingPhotoURLsWithCallBack:(void (^)(void))callback; {
    
    FBRequestConnection *requester = [[FBRequestConnection alloc] init];
    NSString *graphPath = [NSString stringWithFormat:@"/%@/attending", self.event.eventId];
    FBRequest *request = [FBRequest requestWithGraphPath:graphPath parameters:[NSDictionary dictionaryWithObject:ATTENDING_PARAMS forKey:@"fields"] HTTPMethod:@"GET"];
    [requester addRequest:request completionHandler:^(FBRequestConnection *connection,
                                                      FBGraphObject *response,
                                                      NSError *error) {
        if (!error) {
            
            // Ok, so grab an event array
            NSArray *eventArrayFromGraphObject = [response objectForKey:@"data"];
            
            // temp event array to hold
            NSMutableArray *tempPhotoArray = [NSMutableArray array];
            for (id dict in eventArrayFromGraphObject) {
                NSString *photoURL = [[[dict objectForKey:@"picture"] objectForKey:@"data"] objectForKey:@"url"];

                [tempPhotoArray addObject:photoURL];
            }
            
            // Create an immutable copy for the property
            self.attendingFriendsUrls = [tempPhotoArray copy];
            callback();

        }
        
    }];
    
    [requester start];
    
}

#pragma mark - IBActions

- (IBAction)backPressed:(UIBarButtonItem *)sender {
    [self.delegate dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewDidUnload {
    [self setAttendingScrollView:nil];
    [self setFeedScrollView:nil];
    [self setImagePosts:nil];
    [self setMessagePosts:nil];
    [super viewDidUnload];
}
@end
