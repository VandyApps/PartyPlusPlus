//
//  PPPViewController.m
//  PartyPlusPlus
//
//  Created by Scott Andrus on 10/12/12.
//  Copyright (c) 2012 Tapatory. All rights reserved.
//

// Frameworks
#import <QuartzCore/QuartzCore.h>

// Class files
#import "PPPViewController.h"
#import "UIView+Frame.h"
#import "SAViewManipulator.h"
#import "PPPDetailViewController.h"
#import "PPPAppDelegate.h"
#import "SVProgressHUD.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "UIImage+fixOrientation.h"


#define EVENT_PARAMS @"name,picture.type(large),attending,description,location"
#define PHOTO_PARAMS @"source"
#define ATTENDING_PARAMS @"picture"


@interface PPPViewController ()

@end

@implementation PPPViewController
@synthesize pickedTEvent = _pickedTEvent;

#pragma mark - Helper methods
// Get write permissions
- (void)getWritePermissionsWithCompletionBlock:(void (^)(void))block {
    // include any of the "publish" or "manage" permissions
    NSArray *writePermissions = [NSArray arrayWithObjects:@"publish_stream", @"rsvp_event",
 nil];
    [[FBSession activeSession] reauthorizeWithPublishPermissions:writePermissions
                                                 defaultAudience:FBSessionDefaultAudienceFriends
                                               completionHandler:^(FBSession *session, NSError *error) {
                                                   if (!error) {
                                                       block();
                                                   } else {
                                                       if([[error userInfo] objectForKey:@"com.facebook.sdk:ErrorLoginFailedReason"] != nil){
                                                           NSLog(@"%@",[[error userInfo] objectForKey:@"com.facebook.sdk:ErrorLoginFailedReason"]);
                                                       }
                                                   }
                                               }];
}

/*
 * Configure the logged in versus logged out UX
 */
- (void)sessionStateChanged:(NSNotification*)notification {    
    if (FBSession.activeSession.isOpen) {
//        [self.authButton setTitle:@"Logout" forState:UIControlStateNormal];
//        self.userInfoTextView.hidden = NO;

        
        FBRequestConnection *requester = [[FBRequestConnection alloc] init];
        FBRequest *request = [FBRequest requestWithGraphPath:@"me/events" parameters:[NSDictionary dictionaryWithObject:EVENT_PARAMS forKey:@"fields"] HTTPMethod:@"GET"];
        [requester addRequest:request completionHandler:^(FBRequestConnection *connection,
                                                            FBGraphObject *response,
                                                            NSError *error) {
            if (!error) {
                
                // Ok, so grab an event array
                NSArray *eventArrayFromGraphObject = [response objectForKey:@"data"];
                
                // temp event array to hold 
                NSMutableArray *tempEventArray = [NSMutableArray array];
                for (id dict in eventArrayFromGraphObject) {
                    PPPEvent *event = [[PPPEvent alloc] initWithGraphDictionary:dict];
                    [tempEventArray addObject:event];
                }
                
                // Create an immutable copy for the property
//                self.events = [tempEventArray copy];
                

                NSSortDescriptor* sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"date" ascending:YES selector:@selector(compare:)];
                self.events = [tempEventArray sortedArrayUsingDescriptors:[NSArray arrayWithObject:sortDescriptor]];
                
                [self pullAttendingPhotoURLsWithCallBack:^{}];
                // Ok, events are loaded, set up the Main Events scroll view
                [self setupMainEventsScrollView];

                
                // Grab the current page and number of pages while we're here
                self.pageControl.currentPage = 0;
                self.pageControl.numberOfPages = self.events.count;
                
                // Set initial current event
//                self.currentEvent = [self.events objectAtIndex:0];
                
                self.tertiaryEventsScrollView.hidden = NO;
                
                // Show that page control
                self.pageControl.hidden = NO;
                
                // Dismiss our SVProgressHUD
                [SVProgressHUD showSuccessWithStatus:@"Events Loaded!"];
                
            }
            
        }];
        
        [requester start];
        [self pullOtherEventsWithCompetionBlock:^{
            [self setupTertiaryEventsScrollView];
        }];

    }

}


- (void)populateUserDetails {
    PPPAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    [appDelegate requestUserData:^(id sender, id<FBGraphUser> user) {
//        self.userNameLabel.text = user.name;
//        self.userProfilePictureView.profileID = [user objectForKey:@"id"];
//        NSLog(@"%@", user.name);
    }];
}

#pragma mark - Facebook API Calls
- (void)pullOtherEventsWithCompetionBlock:(void (^)(void))block {
    // Query to fetch the active user's friends, limit to 25.
    NSString *query =
    @"SELECT eid, name, venue, location, start_time, pic_big FROM event where eid IN "
    @"(SELECT eid from event_member WHERE uid = me() AND rsvp_status = 'not_replied')";
    // Set up the query parameter
    NSDictionary *queryParam =
    [NSDictionary dictionaryWithObjectsAndKeys:query, @"q", nil];
    // Make the API request that uses FQL
    [FBRequestConnection startWithGraphPath:@"/fql"
                                 parameters:queryParam
                                 HTTPMethod:@"GET"
                          completionHandler:^(FBRequestConnection *connection,
                                              id result,
                                              NSError *error) {
                              if (error) {
                                  NSLog(@"Error: %@", [error localizedDescription]);
                              } else {                                  
                                  // Ok, so grab an event array
                                  NSArray *eventArrayFromFQL = [result objectForKey:@"data"];
                                  
                                  // temp event array to hold
                                  NSMutableArray *tempEventArray = [NSMutableArray array];
                                  for (id dict in eventArrayFromFQL) {
                                      PPPEvent *event = [[PPPEvent alloc] initWithFQLDictionary:dict];
                                      [tempEventArray addObject:event];
                                  }
                                  self.tEvents = tempEventArray;
                              }
                              block();
                          }];
}

- (void)uploadImage:(UIImage *)image {
    
    image = image.fixOrientation;
    FBRequestConnection *requester = [[FBRequestConnection alloc] init];
    NSString *graphPath = [NSString stringWithFormat:@"/%@/photos", self.currentEvent.eventId];
    FBRequest *request = [FBRequest requestWithGraphPath:graphPath parameters:[NSDictionary dictionaryWithObject:image forKey:PHOTO_PARAMS] HTTPMethod:@"POST"];
    [requester addRequest:request completionHandler:^(FBRequestConnection *connection,
                                                      FBGraphObject *response,
                                                      NSError *error) {
        if (!error) {
            //
        }
    }];
    
    [requester start];
}

- (void)rsvpEventWithEID:(NSString *)eid andRSVP:(NSString *)rsvp {
    FBRequestConnection *requester = [[FBRequestConnection alloc] init];
    NSString *graphPath = [NSString stringWithFormat:@"%@/%@", eid, rsvp];
    FBRequest *request = [FBRequest requestWithGraphPath:graphPath parameters:nil HTTPMethod:@"POST"];
    [requester addRequest:request completionHandler:^(FBRequestConnection *connection,
                                                      FBGraphObject *response,
                                                      NSError *error) {
        if (!error) {
            // do stuff
        }
    }];
    
    [requester start];
}

- (void)pullAttendingPhotoURLsWithCallBack:(void (^)(void))callback; {
    for (size_t i = 0; i < self.events.count; ++i) {
        FBRequestConnection *requester = [[FBRequestConnection alloc] init];
        NSString *graphPath = [NSString stringWithFormat:@"/%@/attending", [[self.events objectAtIndex:i] eventId]];
        FBRequest *request = [FBRequest requestWithGraphPath:graphPath parameters:[NSDictionary dictionaryWithObject:ATTENDING_PARAMS forKey:@"fields"] HTTPMethod:@"GET"];
        [requester addRequest:request completionHandler:^(FBRequestConnection *connection,
                                                          FBGraphObject *response,
                                                          NSError *error) {
            if (!error) {
                
                // Ok, so grab an event array
                NSArray *eventArrayFromGraphObject = [response objectForKey:@"data"];
                
                // temp event array to hold
                NSMutableArray *tempPhotoArray = [NSMutableArray array];
                for (size_t j = 0; j < MIN(eventArrayFromGraphObject.count, 3); j++) {
                    NSDictionary *dict = [eventArrayFromGraphObject objectAtIndex:j];
                    NSString *photoURL = [[[dict objectForKey:@"picture"] objectForKey:@"data"] objectForKey:@"url"];
                    
                    [tempPhotoArray addObject:photoURL];
                }
                
                
                callback();
                // Create an immutable copy for the property
                [[self.eventViews objectAtIndex:i] setAttendingThumbnails:[tempPhotoArray copy]];
                [[self.eventViews objectAtIndex:i] showThumbnails];
                
            }
            
        }];
        
        [requester start];
    }
    
    
}

#pragma mark - View Controller lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Register for notifications on FB session state changes
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(sessionStateChanged:)
     name:FBSessionStateChangedNotification
     object:nil];
    
    [self customizeUI];
//    [self generateEvents];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if (FBSession.activeSession.isOpen) {
        // If the user's session is active, personalize, but
        // only if this is not deep linking into the order view.
        [self populateUserDetails];
    } else if (FBSession.activeSession.state == FBSessionStateCreatedTokenLoaded) {
        // Check the session for a cached token to show the proper authenticated
        // UI. However, since this is not user intitiated, do not show the login UX.
        PPPAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        [appDelegate openSessionWithAllowLoginUI:NO];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // Present login modal if necessary after the view has been
    // displayed, not in viewWillAppear: so as to allow display
    // stack to "unwind"
    if (FBSession.activeSession.isOpen) {
        //        [self goToSelectedMenu];
        if (self.pageLabel.hidden && self.pageControl.hidden) {
            [SVProgressHUD showWithStatus:@"Loading..."];
        }
    } else if (FBSession.activeSession.isOpen ||
               FBSession.activeSession.state == FBSessionStateCreatedTokenLoaded ||
               FBSession.activeSession.state == FBSessionStateCreatedOpening) {
    } else {
        [self performSegueWithIdentifier:@"SegueToLogin" sender:self];
    }    
    
    [self loadNavBarLogo];

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidUnload {
    [self setCurrentEventView:nil];
    [self setMainEventsScrollView:nil];
    [self setTertiaryEventsScrollView:nil];
    [self setBackgroundView:nil];
    [self setPageLabel:nil];
    [self setPageControl:nil];
    [self setCurrentTEventView:nil];
    [super viewDidUnload];
}

#pragma mark - Utility methods

- (void)loadNavBarLogo {
    // Set the logo on the navigation bar
    UIImageView *logo = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"PlusPlus"]];
    if ([[self.navigationController.navigationBar subviews] count] > 2) {
        NSArray *navSubviews = [self.navigationController.navigationBar subviews];
        
        for (UIView * subview in navSubviews) {
            if ([subview isKindOfClass:[UIImageView class]] && subview != [navSubviews objectAtIndex:0]) {
                [subview removeFromSuperview];
            }
        }
    }
    [self.navigationController.navigationBar addSubview:logo];
    logo.centerX = self.navigationController.navigationBar.centerX;
}

- (void)customizeUI {
    // Set a gradient on the background
    [SAViewManipulator setGradientBackgroundImageForView:self.backgroundView withTopColor:[UIColor colorWithRed:0.11 green:0.11 blue:0.11 alpha:1] /*#1c1c1c*/ andBottomColor:[UIColor colorWithRed:0.278 green:0.278 blue:0.278 alpha:1] /*#474747*/];
    
    // Have the page label initially hidden until cards are loaded
    self.pageLabel.hidden = YES;
    self.pageControl.hidden = YES;
    
    // Round the navigation bar
    [SAViewManipulator roundNavigationBar:self.navigationController.navigationBar];
}

- (void)generateTertiaryEvents {
    // Create a mutable array to mutate events
    NSMutableArray *mutableEvents = [NSMutableArray array];
    
    PPPEvent *event;
    
    for (size_t i = 0; i < 5; ++i) {
        event = [[PPPEvent alloc] init];
        // Set the event properties
        // TODO: Change this to dynamic events
        event.eventName = [NSString stringWithFormat:@"HackNashville %zu", i + 1];
        event.locationString = @"7 Lea Ave.";
        event.dateString = @"Tonight\n7 PM";
        event.image = [UIImage imageNamed:@"480"];
        
        // Add it to the list of mutable events
        [mutableEvents addObject:event];
    }
    
    // Put it into the events array
    self.tEvents = [mutableEvents copy];
}

- (void)generateEvents {
    // Create a mutable array to mutate events
    NSMutableArray *mutableEvents = [NSMutableArray array];

    PPPEvent *event;
    
    for (size_t i = 0; i < 10; ++i) {
        event = [[PPPEvent alloc] init];
        // Set the event properties
        // TODO: Change this to dynamic events
        event.eventName = [NSString stringWithFormat:@"HackNashville %zu", i + 1];
        event.locationString = @"7 Lea Ave.";
        event.dateString = @"Tonight\n7 PM";
        event.image = [UIImage imageNamed:@"480"];
        
        // Add it to the list of mutable events
        [mutableEvents addObject:event];
    }
    
    // Put it into the events array
    self.events = [mutableEvents copy];
}

- (void)refresh {
    [SVProgressHUD showWithStatus:@"Refreshing..."];
    if (FBSession.activeSession.isOpen) {
        //        [self.authButton setTitle:@"Logout" forState:UIControlStateNormal];
        //        self.userInfoTextView.hidden = NO;
        
        
        FBRequestConnection *requester = [[FBRequestConnection alloc] init];
        FBRequest *request = [FBRequest requestWithGraphPath:@"me/events" parameters:[NSDictionary dictionaryWithObject:EVENT_PARAMS forKey:@"fields"] HTTPMethod:@"GET"];
        [requester addRequest:request completionHandler:^(FBRequestConnection *connection,
                                                          FBGraphObject *response,
                                                          NSError *error) {
            if (!error) {
                
                // Ok, so grab an event array
                NSArray *eventArrayFromGraphObject = [response objectForKey:@"data"];
                
                // temp event array to hold
                NSMutableArray *tempEventArray = [NSMutableArray array];
                for (id dict in eventArrayFromGraphObject) {
                    PPPEvent *event = [[PPPEvent alloc] initWithGraphDictionary:dict];
                    [tempEventArray addObject:event];
                }
                
                // Create an immutable copy for the property
                //                self.events = [tempEventArray copy];
                
                
                NSSortDescriptor* sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"date" ascending:YES selector:@selector(compare:)];
                self.events = [tempEventArray sortedArrayUsingDescriptors:[NSArray arrayWithObject:sortDescriptor]];
                
                [self pullAttendingPhotoURLsWithCallBack:^{}];
                // Ok, events are loaded, set up the Main Events scroll view
                [self setupMainEventsScrollView];
                
                
                // Grab the current page and number of pages while we're here
//                self.pageControl.currentPage = 0;
                self.pageControl.numberOfPages = self.events.count;
                
                // Set initial current event
                self.currentEvent = [self.events objectAtIndex:0];
                
                self.tertiaryEventsScrollView.hidden = NO;
                
                [self.mainEventsScrollView scrollRectToVisible:CGRectMake(0, 0, self.mainEventsScrollView.width, self.mainEventsScrollView.height) animated:YES];
                
                // Show that page control
                self.pageControl.hidden = NO;
                
                // Dismiss our SVProgressHUD
                [SVProgressHUD showSuccessWithStatus:@"Events Refreshed!"];
                
            }
            else [SVProgressHUD showErrorWithStatus:@"Didn't work. :("];
        }];
        
        [requester start];
        [self pullOtherEventsWithCompetionBlock:^{
            [self setupTertiaryEventsScrollView];
        }];
        
        
    }
    [self setupMainEventsScrollView];
}

- (void)setupMainEventsScrollView {
    
    // Remove all drafts currently in the scrollview
    for (UIView *view in self.mainEventsScrollView.subviews) {
        [view removeFromSuperview];
    }
    
    // Flush the local drafts set
    NSMutableArray *mutableEvents = [self.eventViews mutableCopy];
    [mutableEvents removeAllObjects];
    self.eventViews = [mutableEvents copy];
    
    // Set the content size first
    self.mainEventsScrollView.contentSize = CGSizeMake(self.events.count * self.mainEventsScrollView.width, self.mainEventsScrollView.height);
    
    // Create a mutable array of event views
    NSMutableArray *mutableEventViews = [NSMutableArray array];
    
    // Create an event view pointer
    PPPMainEventView *view;
    
    // For each event
    for (size_t i = 0; i < self.events.count; ++i) {

        // Allocate and initialize the associated view
        view = [[PPPMainEventView alloc] init];
        [view addSubview:[[[NSBundle mainBundle] loadNibNamed:@"PPPMainEventView" owner:view options:nil] objectAtIndex:0]];
        
        // Grab the one from interface builder
        view.frame = self.currentEventView.frame;
        view.left += self.mainEventsScrollView.width * i;
        
        // Load the corresponding event
        [view loadEvent:[self.events objectAtIndex:i]];

        // Add a target to the button
        UIButton *detailButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, view.width, view.height)];
        [detailButton addTarget:self action:@selector(goToDetail:) forControlEvents:UIControlEventTouchUpInside];
        
        // Add the detail button to the view
        [view addSubview:detailButton];
        detailButton.size = view.size;
        
        // Add it to the scroll view
        [self.mainEventsScrollView addSubview:view];
        
        // Style the event view
        [self styleMainEventView:view];
        
        // Add object to the mutable event views array
        [mutableEventViews addObject:view];
    }
    
    // Copy into the event views property
    self.eventViews = [mutableEventViews copy];
}

- (void)setupTertiaryEventsScrollView {
    
    // Set the content size first
    self.tertiaryEventsScrollView.contentSize = CGSizeMake(self.tEvents.count * self.tertiaryEventsScrollView.width / 3, self.tertiaryEventsScrollView.height);
    
    // Create a mutable array of event views
    NSMutableArray *mutableEventViews = [NSMutableArray array];
    
    // Create an event view pointer
    PPPTertiaryEventView *view;
    
    // For each event
    for (size_t i = 0; i < self.tEvents.count; ++i) {
        
        // Allocate and initialize the associated view
        view = [[PPPTertiaryEventView alloc] init];
        [view addSubview:[[[NSBundle mainBundle] loadNibNamed:@"PPPTertiaryEventView" owner:view options:nil] objectAtIndex:0]];
        
        // Start asychroniously downloading the photo
        PPPEvent *event = [self.tEvents objectAtIndex:i];
        [self downloadPhoto:event.imageURL forImageView:view.imageView];
        
        // Grab the one from interface builder
        view.frame = self.currentTEventView.frame;
        
        view.left += (self.currentTEventView.width + 21) * (i % 3);
        view.left += self.tertiaryEventsScrollView.width * (i / 3);
        
        // Load the corresponding event
        [view loadEvent:[self.tEvents objectAtIndex:i]];
        
        // Add a target to the button
        UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, view.width, view.height)];
        [button addTarget:self action:@selector(rsvpToEvent:) forControlEvents:UIControlEventTouchUpInside];
        
        // Add the detail button to the view
        [view addSubview:button];
        button.size = view.size;
        
        // Add it to the scroll view
        [self.tertiaryEventsScrollView addSubview:view];
        
        // Style the event view
        [self styleTertiaryEventView:view];
        
        // Add object to the mutable event views array
        [mutableEventViews addObject:view];
    }
    
    // Copy into the event views property
    self.tEventViews = [mutableEventViews copy];
}

- (void)goToDetail:(UIButton *)sender {
    [self performSegueWithIdentifier:@"goToDetail" sender:self.currentEvent];
}

- (void)rsvpToEvent:(UIButton *)sender {
    PPPTertiaryEventView *eventView = (PPPTertiaryEventView *)sender.superview;
    PPPEvent *tEvent = eventView.event;
    NSString *title = [NSString stringWithFormat:@"RSVP for %@", tEvent.eventName];
    self.pickedTEvent = tEvent;
   UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:title delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Attending", @"Maybe", @"Not Attending", nil];
    
    [self getWritePermissionsWithCompletionBlock:^{
        [actionSheet showInView:[[UIApplication sharedApplication] keyWindow]];
    }];
    
}

- (void)styleMainEventView:(PPPMainEventView *)mainEventView {
    [SAViewManipulator addBorderToView:mainEventView withWidth:1 color:[UIColor blackColor] andRadius:10];
    mainEventView.clipsToBounds = YES;
}

- (void)styleTertiaryEventView:(PPPTertiaryEventView *)eventView {
    [SAViewManipulator addBorderToView:eventView.imageView withWidth:1 color:[UIColor blackColor] andRadius:8];
    eventView.imageView.clipsToBounds = YES;
}

#pragma mark - UIScrollView delegate

- (void)scrollViewDidScroll:(UIScrollView *)sender {
    // Update the page when more than 50% of the previous/next page is visible
    CGFloat pageWidth = self.mainEventsScrollView.width;
    int page = floor((self.mainEventsScrollView.contentOffset.x - pageWidth / 2) / pageWidth) + 1;

    self.pageLabel.text = [NSString stringWithFormat:@"%d out of %d", page + 1, self.events.count];
    self.pageControl.currentPage = page;
    
    if (page != [self.events indexOfObject:self.currentEvent] && page <= self.events.count && page >= 0) {
        self.currentEvent = [self.events objectAtIndex:page];
    }
}


#pragma mark - Storyboard methods
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
    if ([segue.identifier isEqualToString:@"goToDetail"]) {
        UINavigationController *nav = (UINavigationController *)segue.destinationViewController;
        PPPDetailViewController *dvc = (PPPDetailViewController *)nav.topViewController;
        dvc.event = sender;
        dvc.delegate = self;
        dvc.title = self.currentEvent.eventName;
    } else if ([segue.identifier isEqualToString:@"segueToLogin"]) {
        
    }
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
    [self getWritePermissionsWithCompletionBlock:^{
        [self startCameraControllerFromViewController: self
                                        usingDelegate: self];
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
        
        // Attempted multithreading, but broke photo upload
        
        dispatch_queue_t downloadQueue = dispatch_queue_create("image downloader", NULL);
        [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
        dispatch_async(downloadQueue, ^{
            //Upload image to event
            [self uploadImage:imageToSave];
            
            // returns to main thread
            dispatch_sync(dispatch_get_main_queue(), ^{
                [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
            });
        });
//        dispatch_release(downloadQueue);
        
        
//        [self uploadImage:imageToSave];


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


#pragma mark - Downloading Images
- (void)downloadPhoto:(NSString *)urlStr forImageView:(UIImageView*)imageView {
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
//        dispatch_release(downloadQueue);
}

#pragma mark - Actionsheet Delegate Methods
// Called when a button is clicked. The view will be automatically dismissed after this call returns
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    PPPEvent *tEvent = self.pickedTEvent;
    NSString *rsvpString = nil;
    if (buttonIndex == 0) {
        NSLog(@"Attending");
        rsvpString = @"attending";
    } else if (buttonIndex == 1) {
        NSLog(@"Maybe");
        rsvpString = @"unsure";
    } else if (buttonIndex == 2) {
        NSLog(@"Not Attending");
        rsvpString = @"declined";
    }
    if (buttonIndex == 0 || buttonIndex == 1 || buttonIndex == 2) {
        [self rsvpEventWithEID:[tEvent.eventId stringValue] andRSVP:rsvpString];
    }
    [self refresh];
}

@end
