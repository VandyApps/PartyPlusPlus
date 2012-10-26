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
#import "PPPImagePost.h"
#import "PPPMessagePost.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "UIImage+fixOrientation.h"
#import "PhotoDetailViewController.h"
#import <dispatch/dispatch.h>

#import <Twitter/Twitter.h>
#import <Accounts/Accounts.h>

#define WALL_PHOTO_PARAMS @"source"
#define ATTENDING_PARAMS @"picture"
#define FEED_PARAMS @"message,from"
#define PHOTO_PARAMS @"source"


@interface PPPDetailViewController ()

@property (strong, nonatomic) IBOutlet UILabel *noPhotosLabel;

@end

@implementation PPPDetailViewController
@synthesize messagePosts;
@synthesize imagePosts;
@synthesize attendingScrollView;
@synthesize attendingFriendsUrls;
@synthesize photosScrollView;
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
    [self pullImagePostURLsWithCallBack:^{
        [self setupPhotosScrollView];
    }];
    [self pullAttendingPhotoURLsWithCallBack:^{
        [self setupAttendingScrollView];
    }];
    [self pullMessagePostsWithCallBack:^{
        // nothing to do
    }];
    
    
    
    [self customizeUI];
}
//
//- (void)viewDidAppear:(BOOL)animated {
//    [self clearNavBarLogo];
//}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Utility methods

- (void)clearNavBarLogo {
    NSArray *navSubviews = [self.navigationController.navigationBar subviews];
    //    NSLog(@"%@", navSubviews);
    for (UIView * subview in navSubviews) {
        if ([subview isKindOfClass:[UIImageView class]] && subview != [navSubviews objectAtIndex:0]) {
            [subview removeFromSuperview];
        }
    }
}

- (void)customizeUI {
    [SAViewManipulator setGradientBackgroundImageForView:self.view withTopColor:[UIColor colorWithRed:0.91 green:0.91 blue:0.91 alpha:1] andBottomColor:[UIColor colorWithRed:0.69 green:0.69 blue:0.69 alpha:1]];
    
    [SAViewManipulator setGradientBackgroundImageForView:self.attendingScrollViewBackgroundView withTopColor:[UIColor colorWithRed:0.11 green:0.11 blue:0.11 alpha:1] /*#1c1c1c*/ andBottomColor:[UIColor colorWithRed:0.278 green:0.278 blue:0.278 alpha:1] /*#474747*/];
    [SAViewManipulator setGradientBackgroundImageForView:self.photosScrollViewBackgroundView withTopColor:[UIColor colorWithRed:0.11 green:0.11 blue:0.11 alpha:1] /*#1c1c1c*/ andBottomColor:[UIColor colorWithRed:0.278 green:0.278 blue:0.278 alpha:1] /*#474747*/];
    
    [SAViewManipulator setGradientBackgroundImageForView:self.friendsHeaderView withTopColor:[UIColor colorWithRed:0.91 green:0.91 blue:0.91 alpha:1] andBottomColor:[UIColor colorWithRed:0.65 green:0.65 blue:0.65 alpha:1]];
    
    [SAViewManipulator setGradientBackgroundImageForView:self.photoStreamHeaderView withTopColor:[UIColor colorWithRed:0.91 green:0.91 blue:0.91 alpha:1] andBottomColor:[UIColor colorWithRed:0.65 green:0.65 blue:0.65 alpha:1]];
    
    // Round the navigation bar
    [SAViewManipulator roundNavigationBar:self.navigationController.navigationBar];
    
    [self downloadPhoto:self.event.imageURL];
    
    /* Gloss twitter button */
    
    [SAViewManipulator setGradientBackgroundImageForView:self.twitterButton withTopColor:[UIColor colorWithRed:0.286 green:0.894 blue:0.961 alpha:1] /*#49e4f5*/ andBottomColor:[UIColor colorWithRed:0.055 green:0.698 blue:0.769 alpha:1] /*#0eb2c4*/];
    [SAViewManipulator addBorderToView:self.twitterButton withWidth:.5 color:[UIColor blackColor] andRadius:10];
    self.twitterButton.clipsToBounds = YES;
    
    //    UIImageView *fbIcon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"fb64"]];
    //    [self.loginButton addSubview:fbIcon];
    //    fbIcon.frame = CGRectMake(8, self.loginButton.height / 2, 80, 80);
    //    fbIcon.centerY = self.loginButton.centerY;
    
    // Round the navigation bar
    //    [SAViewManipulator roundNavigationBar:self.navigationController.navigationBar];
    
    self.view.clipsToBounds = YES;
}

#pragma mark - ScrollView Methods
- (void)setupAttendingScrollView {
    
    // Create a main event view pointer
    UIImageView *view;
    
    self.attendingScrollView.contentSize = CGSizeMake((self.thumbnailImageView.width + 5) * self.attendingFriendsUrls.count - 5, self.thumbnailImageView.height);
    
    
    // Create events
    for (size_t i = 0; i < self.attendingFriendsUrls.count; ++i) {
        
        // Allocate and initialize the event
        view = [[UIImageView alloc] initWithFrame:self.thumbnailImageView.frame];
        
        view.left = (self.thumbnailImageView.width + 5) * i;
        
        // Set the labels
        [self downloadPhoto:[self.attendingFriendsUrls objectAtIndex:i] forImageView:view];
        
        [SAViewManipulator addBorderToView:view withWidth:1.5 color:[UIColor whiteColor] andRadius:22];
        view.clipsToBounds = YES;
        //        [SAViewManipulator addShadowToView:view withOpacity:.8 radius:3 andOffset:CGSizeMake(1, 1)];
        
        // Add it to the subview
        [self.attendingScrollView addSubview:view];
        
    }
    
}

#pragma mark - TableView Methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return messagePosts.count;
}

// Row display. Implementers should *always* try to reuse cells by setting each cell's reuseIdentifier and querying for available reusable cells with dequeueReusableCellWithIdentifier:
// Cell gets various attributes set automatically based on table (separators) and data source (accessory views, editing controls)

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"postCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    }
    cell.textLabel.text = [self.messagePosts objectAtIndex:indexPath.row];
    return cell;
}

#pragma mark - ScrollView Methods
- (void)setupPhotosScrollView {
    self.imageDict = [NSMutableArray array];
    self.buttonDict = [NSMutableArray array];
    
    if (imagePosts.count == 0) {
        self.noPhotosLabel.hidden = NO;
    } else self.noPhotosLabel.hidden = YES;
    
    // Create a main event view pointer
    UIImageView *view;
    
    self.photosScrollView.contentSize = CGSizeMake((self.wallPhotoImageView.width + 10) * self.imagePosts.count - 10, self.wallPhotoImageView.height);
    
    // Create 10 events
    for (size_t i = 0; i < self.imagePosts.count; ++i) {
        
        // Allocate and initialize the event
        view = [[UIImageView alloc] initWithFrame:self.wallPhotoImageView.frame];
        
        
        UIView *containerView = [[UIView alloc] initWithFrame:view.frame];
        [containerView addSubview:view];
        
        containerView.left = (self.wallPhotoImageView.width + 10) * i;
        
        // Set the labels
        view.hidden = YES;
        PPPImagePost *imagePost = [self.imagePosts objectAtIndex:i];
        [self downloadPhoto:imagePost.imageURL forImageView:view];
        
        UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, view.width, view.height)];
        [button addTarget:self action:@selector(showPhoto:) forControlEvents:UIControlEventTouchUpInside];
        [containerView addSubview:button];
        
        [self.imageDict addObject:view];
        [self.buttonDict addObject:button];
        
        [SAViewManipulator addBorderToView:containerView withWidth:3 color:[UIColor whiteColor] andRadius:0];
        [SAViewManipulator addShadowToView:containerView withOpacity:.8 radius:3 andOffset:CGSizeMake(1, 1)];
        containerView.clipsToBounds = YES;
        
        view.contentMode = UIViewContentModeScaleAspectFill;
        
        // Add it to the subview
        [self.photosScrollView addSubview:containerView];
        
    }
    
    
    //    }
    
}

- (void)showPhoto:(UIButton *)sender {
    [self performSegueWithIdentifier:@"displayPhoto" sender:[self.imageDict objectAtIndex:[self.buttonDict indexOfObject:sender]]];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    PhotoDetailViewController *pdvc = (PhotoDetailViewController *)[segue.destinationViewController topViewController];
    pdvc.image = [sender image];
}

- (void)downloadPhoto:(NSString *)urlStr {
    self.coverImageView.clipsToBounds = YES;
    if (!self.event.image) {
        // Download photo
        UIBarButtonItem *oldItem = self.navigationController.navigationItem.rightBarButtonItem;
        UIActivityIndicatorView *loading = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        [loading startAnimating];
        [self.navigationController.navigationItem setRightBarButtonItem: [[UIBarButtonItem alloc] initWithCustomView:loading]];
        
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
                UIImage *image = [UIImage imageWithData:imgUrl];
                if (image.size.width >= self.coverImageView.size.width && image.size.height >= self.coverImageView.size.height) {
                    //                    self.coverImageView.contentMode = UIViewContentModeCenter;
                }
                [self.coverImageView setImage:[UIImage imageWithData:imgUrl]];
                [loading stopAnimating];
                [loading removeFromSuperview];
                [self.navigationController.navigationItem setRightBarButtonItem:oldItem];
            });
        });
        //        dispatch_release(downloadQueue);
    } else [self.coverImageView setImage:self.event.image];
}

#pragma mark - Twitter

- (IBAction)postToTwitter {
    // Create the view controller
    TWTweetComposeViewController *twitter = [[TWTweetComposeViewController alloc] init];
    
    // Optional: set an image, url and initial text
    NSArray *firstWords = [self.event.eventName componentsSeparatedByString:@" "];// subarrayWithRange:wordRange];
    
    NSString *twitterTags = [NSString string];
    for (NSString *word in firstWords) {
        twitterTags = [twitterTags stringByAppendingString:[NSString stringWithFormat:@"#%@ ", word]];
    }
    
    [twitter setInitialText:twitterTags];
    
    // Show the controller
    [self presentModalViewController:twitter animated:YES];
    
    //    // Called when the tweet dialog has been closed
    //    twitter.completionHandler = ^(TWTweetComposeViewControllerResult result)
    //    {
    //        NSString *title = @"Tweet Status";
    //        NSString *msg;
    //
    //        if (result == TWTweetComposeViewControllerResultCancelled)
    //            msg = @"Tweet compostion was canceled.";
    //        else if (result == TWTweetComposeViewControllerResultDone)
    //            msg = @"Tweet composition completed.";
    //
    //        // Show alert to see how things went...
    //        UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:title message:msg delegate:self cancelButtonTitle:@"Okay" otherButtonTitles:nil];
    //        [alertView show];
    //
    //        // Dismiss the controller
    //        [self dismissModalViewControllerAnimated:YES];
    //    };
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
                imageView.hidden = NO;
                [loading stopAnimating];
                [loading removeFromSuperview];
            });
        });
        //        dispatch_release(downloadQueue);
    }
}

- (void)pullMessagePostsWithCallBack:(void (^)(void))callback; {
    
    FBRequestConnection *requester = [[FBRequestConnection alloc] init];
    NSString *graphPath = [NSString stringWithFormat:@"/%@/feed", self.event.eventId];
    FBRequest *request = [FBRequest requestWithGraphPath:graphPath parameters:[NSDictionary dictionaryWithObject:FEED_PARAMS forKey:@"fields"] HTTPMethod:@"GET"];
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
                    PPPMessagePost *messagePost = [[PPPMessagePost alloc] initWithMessage:message andDateString:dateString andPoster:poster];
                    [tempPostArray addObject:messagePost];
                }
                
            }
            
            // Create an immutable copy for the property
            self.messagePosts = [tempPostArray copy];
            callback();
        }
        
    }];
    
    [requester start];
    
}

- (void)pullImagePostURLsWithCallBack:(void (^)(void))callback; {
    
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
                PPPImagePost *imagePost = [[PPPImagePost alloc] initWithImageUrl:photoURL andDateString:dateString andPoster:poster];
                [tempPostArray addObject:imagePost];
            }
            
            // Create an immutable copy for the property
            self.imagePosts = [tempPostArray copy];
            callback();
            
        }
        
    }];
    
    [requester start];
    
}

- (void)pullAttendingPhotoURLsWithCallBack:(void (^)(void))callback; {
    
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

#pragma mark - Camera Methods
- (BOOL) startCameraControllerFromViewController: (UIViewController*) controller
                                   usingDelegate: (id <UIImagePickerControllerDelegate,
                                                   UINavigationControllerDelegate>) delegate {
    
    if (([UIImagePickerController isSourceTypeAvailable:
          UIImagePickerControllerSourceTypeCamera] == NO)
        || (delegate == nil)
        || (controller == nil))
        return NO;
    
    
    UIImagePickerController *cameraUI = [[UIImagePickerController alloc] init];
    cameraUI.sourceType = UIImagePickerControllerSourceTypeCamera;
    
    // Displays a control that allows the user to choose picture or
    // movie capture, if both are available:
    cameraUI.mediaTypes =
    [UIImagePickerController availableMediaTypesForSourceType:
     UIImagePickerControllerSourceTypeCamera];
    
    // Hides the controls for moving & scaling pictures, or for
    // trimming movies. To instead show the controls, use YES.
    cameraUI.allowsEditing = NO;
    
    cameraUI.delegate = delegate;
    
    cameraUI.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;
    [controller presentViewController:cameraUI animated:YES completion:nil];
    return YES;
}

- (IBAction)showCameraUI:(id)sender {
    [self startCameraControllerFromViewController: self
                                    usingDelegate: self];
    [self getWritePermissions];
}

#pragma mark - Helper methods
// Get write permissions
- (void)getWritePermissions {
    // include any of the "publish" or "manage" permissions
    NSArray *writePermissions = [NSArray arrayWithObjects:@"publish_stream", nil];
    [[FBSession activeSession] reauthorizeWithPublishPermissions:writePermissions
                                                 defaultAudience:FBSessionDefaultAudienceFriends
                                               completionHandler:^(FBSession *session, NSError *error) {
                                                   /* handle success + failure in block */
                                                   if(!error){
                                                       
                                                   } else {
                                                       if([[error userInfo] objectForKey:@"com.facebook.sdk:ErrorLoginFailedReason"] != nil){
                                                           NSLog(@"%@",[[error userInfo] objectForKey:@"com.facebook.sdk:ErrorLoginFailedReason"]);
                                                       }
                                                   }
                                               }];
}

#pragma mark - Camera Delegate Methods

// For responding to the user tapping Cancel.
- (void) imagePickerControllerDidCancel: (UIImagePickerController *) picker {
    [self dismissModalViewControllerAnimated: YES];
}

// For responding to the user accepting a newly-captured picture or movie
- (void) imagePickerController: (UIImagePickerController *) picker
 didFinishPickingMediaWithInfo: (NSDictionary *) info {
    
    NSString *mediaType = [info objectForKey: UIImagePickerControllerMediaType];
    UIImage *originalImage, *editedImage, *imageToSave;
    
    // Handle a still image capture
    if (CFStringCompare ((CFStringRef) mediaType, kUTTypeImage, 0)
        == kCFCompareEqualTo) {
        
        editedImage = (UIImage *) [info objectForKey:
                                   UIImagePickerControllerEditedImage];
        originalImage = (UIImage *) [info objectForKey:
                                     UIImagePickerControllerOriginalImage];
        
        if (editedImage) {
            imageToSave = editedImage;
        } else {
            imageToSave = originalImage;
        }
        
        // Save the new image (original or edited) to the Camera Roll
        UIImageWriteToSavedPhotosAlbum (imageToSave, nil, nil , nil);
        
        //Upload image to event
        dispatch_queue_t backgroundQueue;
        
        // 1) Add to bottom of initWithHTML:delegate
        backgroundQueue = dispatch_queue_create("downloadQueue", NULL);
        
        // 3) Modify process to be the following
        [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
        dispatch_async(backgroundQueue, ^(void) {
            [self uploadImage:imageToSave];
            dispatch_sync(dispatch_get_main_queue(), ^{
                [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
            });
        });
        
    }
    
    // Handle a movie capture
    if (CFStringCompare ((CFStringRef) mediaType, kUTTypeMovie, 0)
        == kCFCompareEqualTo) {
        
        NSString *moviePath = [[info objectForKey:
                                UIImagePickerControllerMediaURL] path];
        
        if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum (moviePath)) {
            UISaveVideoAtPathToSavedPhotosAlbum (
                                                 moviePath, nil, nil, nil);
        }
    }
    
    [self dismissModalViewControllerAnimated: YES];
}

#pragma mark - Facebook Uploading Methods

- (void)uploadImage:(UIImage *)image {
    
    image = image.fixOrientation;
    FBRequestConnection *requester = [[FBRequestConnection alloc] init];
    NSString *graphPath = [NSString stringWithFormat:@"/%@/photos", self.event.eventId];
    FBRequest *request = [FBRequest requestWithGraphPath:graphPath parameters:[NSDictionary dictionaryWithObject:image forKey:PHOTO_PARAMS] HTTPMethod:@"POST"];
    [requester addRequest:request completionHandler:^(FBRequestConnection *connection,
                                                      FBGraphObject *response,
                                                      NSError *error) {
    }];
    
    [requester start];
    
}


#pragma mark - IBActions

- (IBAction)backPressed:(UIBarButtonItem *)sender {
    [self.delegate dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewDidUnload {
    [self setAttendingScrollView:nil];
    [self setPhotosScrollView:nil];
    [self setImagePosts:nil];
    [self setMessagePosts:nil];
    [self setWallPhotoImageView:nil];
    [self setFriendsHeaderView:nil];
    [self setPhotoStreamHeaderView:nil];
    [self setAttendingScrollViewBackgroundView:nil];
    [self setPhotosScrollViewBackgroundView:nil];
    [self setNoPhotosLabel:nil];
    [self setCoverImageView:nil];
    [self setTwitterButton:nil];
    [super viewDidUnload];
}
@end
