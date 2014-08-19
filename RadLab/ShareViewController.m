//
//  ShareViewController.m
//  RadLab
//
//  Created by Geoff Scott on 10/31/12.
//  Copyright (c) 2012 Totally Rad. All rights reserved.
//

#import "ShareViewController.h"

#import <Accounts/Accounts.h>
#import "ALAssetsLibrary+CustomPhotoAlbum.h"
#import "Appdelegate.h"
#import "Appirater.h"
#import "AppSettings.h"
#import "TRStatistics.h"
#import <ImageIO/ImageIO.h>
#import "MemoryStatistics.h"
#import <MobileCoreServices/UTCoreTypes.h>
#import "PTGButton.h"
#import "PTGNotify.h"
#import <Social/Social.h>
#import "UICommon.h"
#import "UIImage+Resize.h"

static int ddLogLevel = LOG_LEVEL_INFO;

NSString *const FBSessionStateChangedNotification =
    @"com.gettotallyrad.RadLab:FBSessionStateChangedNotification";

NSData* UIImageJPEGRepresentationWithMetadata(UIImage *image, CGFloat compressionQuality, NSDictionary* metadata) {
    NSData* jpeg = [NSData dataWithData:UIImageJPEGRepresentation(image, compressionQuality)];
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)jpeg, NULL);
    CFStringRef uti = CGImageSourceGetType(source);
    NSMutableData* result = [NSMutableData data];
    CGImageDestinationRef dest = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)result, uti, 1, NULL);
    CGImageDestinationAddImageFromSource(dest, source, 0, (__bridge CFDictionaryRef)metadata);
    BOOL success = CGImageDestinationFinalize(dest);
    CFRelease(source);
    CFRelease(dest);
    if (!success) {
        DDLogCError(@"failed to add metadata");
        return jpeg;
    }
    return result;
}

@interface ShareViewController () <UIAlertViewDelegate>
{
    PTGButton* documentInteractionControllerReason;
    CGPoint _saveContentOffset;
    BOOL _currentlySavingRecipe;
}
@property (strong) ALAssetsLibrary* assetsLibrary;
@end

// keep this number in sync with content from the storyboard
static const CGFloat kScrollContentHeight_iphone = 578.0;
static const CGFloat kScrollContentHeight_ipad = 390.0;

@implementation ShareViewController

@synthesize dataController = _dataController;
@synthesize documentInteractionController = _documentInteractionController;
@synthesize scrollView = _scrollView;
@synthesize imageView = _imageView;
@synthesize blurredBackground = _blurredBackground;
@synthesize saveRecipeButton = _saveRecipeButton;
@synthesize renderedButton = _renderedButton;
@synthesize instagramCropButton = _instagramCropButton;
@synthesize instagramWhiteButton = _instagramWhiteButton;
@synthesize instagramFloatButton = _instagramFloatButton;
@synthesize facebookButton = _facebookButton;
@synthesize twitterButton = _twitterButton;
@synthesize openInButton = _openInButton;
@synthesize clipboardButton = _clipboardButton;
@synthesize assetsLibrary = _assetsLibrary;

- (void)dealloc {
    DDLogInfo(@"ShareViewController dealloc (mem %@)", stringWithMemoryInfo());
    [self.popoverDelegate dismissOpenPopover];
    [self.dataController releaseMemoryForShareView:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _saveContentOffset = CGPointMake(0.0, 0.0);
    self.assetsLibrary = [[ALAssetsLibrary alloc] init];
    
    // temp
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillEnterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];

}

- (void)applicationWillEnterForeground:(NSNotification*)notification {
    DDLogInfo(@"ShareViewController applicationWillEnterForeground (mem %@)", stringWithMemoryInfo());
}

- (void)restoreSharedToState:(PTGButton*)btn {
    [btn setEnabled:![self.dataController hasSharedToDestination:btn.shareDestinationCode]];
}

#ifdef USE_APPIRATER
- (BOOL)significantShare:(NSString*)dest {
    return [dest isEqual:@"CR"];
}
#endif

- (void)didShareViaButton:(PTGButton*)btn {
    if (btn != self.openInButton)
        [btn setEnabled:NO];
    NSString* dest = btn.shareDestinationCode;
    [self.dataController didShareToDestination:dest];
  #ifdef USE_APPIRATER
    if ([self significantShare:dest])
        [Appirater userDidSignificantEvent:NO];
  #endif
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if (!_currentlySavingRecipe) {
        // If we're in crash-recovery mode, don't allow going back to the
        // non-existent Tap screen
        self.tapButton.enabled = !self.dataController.crashedOnPreviousRun;

        [self.imageView setImage:[self.dataController currentPreviewAtCurrentStrength]];
        setPreviewStylingForView(self.imageView);

        if (! AppSettings.manager.useSimpleBackground) {
            [self.blurredBackground setImage:blurImage([self.dataController masterPreview])];
        } else {
            [self.blurredBackground setImage:nil];
        }

        [self restoreSharedToState:self.renderedButton];
        [self restoreSharedToState:self.instagramCropButton];
        [self restoreSharedToState:self.instagramWhiteButton];
        [self restoreSharedToState:self.instagramFloatButton];
        [self restoreSharedToState:self.facebookButton];
        [self restoreSharedToState:self.twitterButton];
        [self restoreSharedToState:self.clipboardButton];
        
        [self.saveRecipeButton setEnabled:self.dataController.currentFilterChainIsViableAsRecipe];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    // shouldn't have to do this, but need to make the content taller for all the buttons
    CGFloat height = kScrollContentHeight_iphone;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        height = kScrollContentHeight_ipad;
    [self.scrollView setContentSize:CGSizeMake(self.scrollView.contentSize.width, height)];
    _saveContentOffset = self.scrollView.contentOffset;

    if (!_currentlySavingRecipe) {
        if (!AppSettings.manager.visitedGoScreen) {
            [self.popoverDelegate dismissOpenPopover];
            [PTGNotify displayInitialHelp:@"Help_Go"
                           withAlertTitle:NSLocalizedString(@"SHARE IT", nil)
                               pageNumber:4 ofTotalPageCount:4
                          withButtonTitle:NSLocalizedString(@"Let's Go!", nil)
                      aboveViewController:self
                      withCompletionBlock:^(void){[self.popoverDelegate reopenLastPopover];}];
        }
        [self.dataController startResizingForShareView];
    }
    _currentlySavingRecipe = NO;
}

- (void)viewWillDisappear:(BOOL)animated {
    AppSettings.manager.visitedGoScreen = YES;
    if (!_currentlySavingRecipe) {
        [self.popoverDelegate dismissOpenPopover];
        [self.dataController releaseMemoryForShareView:self];
    }
    [super viewWillDisappear:animated];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    // shouldn't have to do this, but need to make the content taller for all the buttons
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.scrollView setContentSize:CGSizeMake(self.scrollView.contentSize.width, kScrollContentHeight_ipad)];
    } else {
        [self.scrollView setContentSize:CGSizeMake(self.scrollView.contentSize.width, kScrollContentHeight_iphone)];
    }
    _saveContentOffset = self.scrollView.contentOffset;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"showSaveRecipe"]) {
        SaveRecipeViewController *saveRecipeController = (SaveRecipeViewController *)[segue destinationViewController];
        [saveRecipeController setDelegate:self];
        [saveRecipeController setDataController:self.dataController];
        [self.scrollView setContentOffset:CGPointMake(0.0, 0.0) animated:YES];
    }
}

- (NSString*)shareAnnotation {
    return @" #pictapgo_app ";

    // TODO: figure out a better way to embed recipes in shared images
    NSString* recipeCode = self.dataController.recipeCode;
    if ([recipeCode isEqualToString:@""])
        return @" #pictapgo_app ";
    return [NSString stringWithFormat:@" #pictapgo_app [%@]", recipeCode];
}

- (void)my_viewWillUnload {
    DDLogInfo(@"begin will unload Share view (mem %@)", stringWithMemoryInfo());
    [self.dataController releaseMemoryForShareView:self];
    self.assetsLibrary = nil;
    DDLogInfo(@"finish will unload Share view (mem %@)", stringWithMemoryInfo());
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    if (self.isViewLoaded && self.view.window == nil && !_currentlySavingRecipe) {
        [self.popoverDelegate dismissOpenPopover];
        [self my_viewWillUnload];
        self.view = nil;
    }
}

- (IBAction)doBack:(id)sender {
    UINavigationController *navCon = [self navigationController];
    [navCon popViewControllerAnimated:YES];
}

- (IBAction)doChoose:(id)sender {
    UINavigationController *navCon = [self navigationController];
    [self my_viewWillUnload];
    [navCon popToRootViewControllerAnimated:YES];
}

- (IBAction)doSaveReceipe:(id)sender { // AKA doSaveRecipe
    _currentlySavingRecipe = YES;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        SaveRecipeViewController *recipeController = [[SaveRecipeViewController alloc] initWithNibName:@"Popover_Recipe" bundle:nil];
        [recipeController setDataController:self.dataController];
        [recipeController setDelegate:self];
    
        UINavigationController *navCon = [self navigationController];
        [navCon pushViewController:recipeController animated:YES];
    } else {
        [self performSegueWithIdentifier:@"showSaveRecipe" sender:self];
    }
}

- (void)saveImage:(UIImage*)image metadata:(NSDictionary*)metadata{
    [self.assetsLibrary saveImage:image
                                  metadata:metadata
                                   toAlbum:NSLocalizedString(@"PicTapGo", nil)
                           completionBlock:^(NSURL *assetURL, NSError *error) {
                               if (error)
                                   DDLogError(@"Problem writing image %@ to album. error = %@", assetURL, error);
                           }
                              failureBlock:^(NSError *error) {
                                  if (error)
                                      DDLogError(@"Problem writing image to album. error = %@", error);
                              }];
}

- (void)saveImageAndRecipe {
    // Whenever we share to ANY destination, we "virtually" press the
    // "save to camera roll" button to save the image before proceeding.  We
    // also make sure to make that obvious by lighting up the checkmark on
    // that button when we're done.
    if (self.renderedButton.isEnabled) {
        [self.dataController updateMagicWeights];
        [self.dataController saveRecipeToHistory];
        [self.dataController resetAllRecipesInAllFolders];
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationResetStyletSections
                                                            object:self userInfo:nil];
        UIImage *largeImage = self.dataController.currentLarge;
        NSDictionary* metadata = self.dataController.masterMetadata;
        [self saveImage:largeImage metadata:metadata];
        [self didShareViaButton:self.renderedButton];  // prevent multiple saves
    }
}

enum ReadyOrWaiting {
    kCurrentLargeReady,
    kCurrentLargeWaiting
};

- (BOOL)spinForCurrentLargeThenRetry:(id)sender {
    if (self.dataController.currentLargeIsReady)
        return kCurrentLargeReady;

    __block BOOL didWait = NO;
    [self.dataController currentLargeWithWaitBlock:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            didWait = YES;
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                _currentlySavingRecipe = YES;
                [self.popoverDelegate dismissOpenPopover];
            }
            [PTGNotify showSpinnerAboveViewController:self];
        });
    } completionBlock:^(UIImage* image) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (didWait)
            [PTGNotify hideSpinner];
            [self.popoverDelegate reopenLastPopover];
            [sender sendActionsForControlEvents:UIControlEventTouchUpInside];
        });
    }];
    return kCurrentLargeWaiting;
}

- (IBAction)doSaveRendered:(id)sender {
    if ([self spinForCurrentLargeThenRetry:sender] == kCurrentLargeWaiting)
        return;

    // ensure sane calling conventions
    NSAssert(sender == self.renderedButton, @"Unexpected sender in doSaveRendered");

    if (self.renderedButton.isEnabled) {
        [self saveImageAndRecipe];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            _currentlySavingRecipe = YES;
            [self.popoverDelegate dismissOpenPopover];
        }
        [PTGNotify displayMessage:NSLocalizedString(@"Saved to Camera Roll", nil) aboveViewController:self withCompletionBlock:^(void){[self.popoverDelegate reopenLastPopover];}];
        [self didShareViaButton:sender];
        _saveContentOffset = self.scrollView.contentOffset;
    }
}

- (IBAction)doCopyToClipboard:(id)sender {
    if ([self spinForCurrentLargeThenRetry:sender] == kCurrentLargeWaiting)
        return;

    PTGButton* btn = self.clipboardButton;
    if (btn.isEnabled) {
        [self.dataController saveRecipeToHistory];
        
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        NSMutableDictionary *pasteDict = [NSMutableDictionary dictionaryWithCapacity:2];

        // recipe code as text
        NSString* recipeCode = self.dataController.recipeCode;
        [pasteDict setValue:recipeCode forKey:(NSString *)kUTTypeUTF8PlainText];
    
        // image as a JPEG
        UIImage* image = self.dataController.currentLarge;
        NSDictionary* metadata = self.dataController.masterMetadata;
        NSData *data = UIImageJPEGRepresentationWithMetadata(image, 0.95, metadata);
        [pasteDict setValue:data forKey:(NSString *)kUTTypeJPEG];

        [pasteboard setItems:[NSArray arrayWithObject:pasteDict]];
        [self didShareViaButton:btn];
        _saveContentOffset = self.scrollView.contentOffset;
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            _currentlySavingRecipe = YES;
            [self.popoverDelegate dismissOpenPopover];
        }
        [PTGNotify displayMessage:NSLocalizedString(@"Copied to Clipboard", nil) aboveViewController:self withCompletionBlock:^(void){[self.popoverDelegate reopenLastPopover];}];
        [TRStatistics checkpoint:TRCheckpointSavedToClipboard];
    }
}

- (IBAction)doOpenIn:(id)sender {
    if ([self spinForCurrentLargeThenRetry:sender] == kCurrentLargeWaiting)
        return;

    NSString *savePath = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/PicTapGo.jpg"];
    UIImage* image = self.dataController.currentLarge;
    NSDictionary* metadata = self.dataController.masterMetadata;
    [UIImageJPEGRepresentationWithMetadata(image, 0.95, metadata) writeToFile:savePath atomically:YES];
    
    UIDocumentInteractionController* docICont = [UIDocumentInteractionController interactionControllerWithURL:[NSURL fileURLWithPath:savePath]];
    
    // make sure the controller is retained, otherwise we crash when 'docICont' leaves scope
    self.documentInteractionController = docICont;
    documentInteractionControllerReason = self.openInButton;
    [docICont setDelegate:self];
    
    docICont.UTI = (NSString *)kUTTypeJPEG;
    
    CGRect openRect = CGRectZero;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        openRect = self.openInButton.frame;
    }
    if (![docICont presentOpenInMenuFromRect:openRect inView:self.view animated:YES]) {
        [PTGNotify displaySimpleAlert:NSLocalizedString(@"Could not find any apps on this device registered to open JPEG images from another app.", nil)];
    }
}

- (BOOL)imageToInstagram:(UIImage*)image metadata:(NSDictionary*)metadata reason:(PTGButton*)reason {
    BOOL success = NO;

    NSURL* instagramURL = [NSURL URLWithString:@"instagram://app"];
    if ([[UIApplication sharedApplication] canOpenURL:instagramURL]) {
        NSString *savePath = [NSHomeDirectory()
                              stringByAppendingPathComponent:@"Documents/instagram.igo"];
        [UIImageJPEGRepresentationWithMetadata(image, 0.95, metadata) writeToFile:savePath atomically:YES];

        UIDocumentInteractionController* ig = [UIDocumentInteractionController
          interactionControllerWithURL:[NSURL fileURLWithPath:savePath]];

        // make sure the controller is retained, otherwise we crash when 'ig' leaves scope
        self.documentInteractionController = ig;
        documentInteractionControllerReason = reason;
        [ig setDelegate:self];
        
        ig.UTI = @"com.instagram.exclusivegram";
        ig.annotation = [NSDictionary dictionaryWithObject:self.shareAnnotation forKey:@"InstagramCaption"];
        CGRect openRect = CGRectZero;
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            openRect = reason.frame;
        }
        success = [ig presentOpenInMenuFromRect:openRect inView:self.view animated:YES];
    } else {
        [PTGNotify displaySimpleAlert:NSLocalizedString(@"Could not find Instagram installed on this device", nil)];
    }

    if (!success)
        [TRStatistics checkpoint:TRCheckpointCancelledShareIgram];

    return success;
}

static const int INSTAGRAM_MIN_SIZE = 612;
static const int INSTAGRAM_MAX_SIZE = 1224;

- (IBAction)doShareInstagramBorder:(id)sender {
    if ([self spinForCurrentLargeThenRetry:sender] == kCurrentLargeWaiting)
        return;

    PTGButton* btn = self.instagramWhiteButton;
    if (btn.isEnabled) {
        [self saveImageAndRecipe];
        UIImage* source = self.dataController.currentLarge;
        CGFloat axis = MAX(source.size.width, source.size.height);
        axis = MIN(INSTAGRAM_MAX_SIZE, MAX(axis, INSTAGRAM_MIN_SIZE));
        CGSize bounds = CGSizeMake(axis, axis);
        UIImage *finalImage = [source resizedImageWithContentMode:UIViewContentModeScaleAspectFit
                                                           bounds:bounds
                                                      borderWidth:0
                                             interpolationQuality:kCGInterpolationHigh];
        NSDictionary* metadata = self.dataController.masterMetadata;
        if (![self imageToInstagram:finalImage metadata:metadata reason:btn]) {
            DDLogError(@"Bummer! Failed to open Instagram");
        }
    }
}

- (IBAction)doShareInstagramCrop:(id)sender {
    if ([self spinForCurrentLargeThenRetry:sender] == kCurrentLargeWaiting)
        return;

    PTGButton* btn = self.instagramCropButton;
    if (btn.isEnabled) {
        [self saveImageAndRecipe];
        UIImage* source = self.dataController.currentLarge;
        CGFloat axis = MIN(source.size.width, source.size.height);
        axis = MIN(INSTAGRAM_MAX_SIZE, MAX(axis, INSTAGRAM_MIN_SIZE));
        CGSize bounds = CGSizeMake(axis, axis);
        UIImage* finalImage = [source resizedImageWithContentMode:UIViewContentModeScaleAspectFill
                                                           bounds:bounds
                                                      borderWidth:0
                                             interpolationQuality:kCGInterpolationHigh];
        NSDictionary* metadata = self.dataController.masterMetadata;
        if (![self imageToInstagram:finalImage metadata:metadata reason:btn]) {
            DDLogError(@"Bummer! Failed to open Instagram");
        }
    }
}

- (IBAction)doShareInstagramFloat:(id)sender {
    if ([self spinForCurrentLargeThenRetry:sender] == kCurrentLargeWaiting)
        return;
    
    PTGButton* btn = self.instagramFloatButton;
    if (btn.isEnabled) {
        [self saveImageAndRecipe];
        UIImage* source = self.dataController.currentLarge;
        CGFloat axis = MAX(source.size.width, source.size.height);
        axis = MIN(INSTAGRAM_MAX_SIZE, MAX(axis, INSTAGRAM_MIN_SIZE));
        CGSize bounds = CGSizeMake(axis, axis);
        UIImage *finalImage = [source resizedImageWithContentMode:UIViewContentModeScaleAspectFit
                                                           bounds:bounds
                                                      borderWidth:40
                                             interpolationQuality:kCGInterpolationHigh];
        NSDictionary* metadata = self.dataController.masterMetadata;
        if (![self imageToInstagram:finalImage metadata:metadata reason:btn]) {
            DDLogError(@"Bummer! Failed to open Instagram");
        }
    }
}

// wrapper for sharing to Facebook or Twitter
- (void)shareTo:(NSString*)serviceType via:(id)sender
  completion:(SLComposeViewControllerCompletionHandler)completionHandler
  failureMessage:(NSString*)failureMessage
{
    if ([SLComposeViewController isAvailableForServiceType:serviceType]) {
        UIImage* image = self.dataController.currentLarge;
        SLComposeViewController* tweetSheet = [SLComposeViewController composeViewControllerForServiceType:serviceType];
        SLComposeViewControllerCompletionHandler __block completionWrapper = ^(SLComposeViewControllerResult result){
            [tweetSheet dismissViewControllerAnimated:YES completion:nil];
            completionHandler(result);
        };
        [tweetSheet setCompletionHandler:completionWrapper];
        [tweetSheet setInitialText:self.shareAnnotation];
        [tweetSheet addImage:image];
        [self presentViewController:tweetSheet animated:YES completion:nil];
    } else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Account Message", nil)
                                                        message:failureMessage
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                              otherButtonTitles:nil];
        [alert show];
    }
}

- (void)facebookCompletion:(NSNumber*)result {
    switch (result.intValue) {
    case SLComposeViewControllerResultCancelled:
        [TRStatistics checkpoint:TRCheckpointCancelledShareFacebook];
        break;
    case SLComposeViewControllerResultDone:
        [self didShareViaButton:self.facebookButton];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            _currentlySavingRecipe = YES;
            [self.popoverDelegate dismissOpenPopover];
        }
        [PTGNotify displayMessage:NSLocalizedString(@"Shared to Facebook", nil) aboveViewController:self withCompletionBlock:^(void){[self.popoverDelegate reopenLastPopover];}];
        break;
    }
}

- (IBAction)doShareFacebook:(id)sender {
    if ([self spinForCurrentLargeThenRetry:sender] == kCurrentLargeWaiting)
        return;

    if (self.facebookButton.isEnabled) {
        [self saveImageAndRecipe];
        SLComposeViewControllerCompletionHandler completionHandler = ^(SLComposeViewControllerResult result){
            NSNumber *resultNum = [NSNumber numberWithInt:result];
            [self performSelectorOnMainThread:@selector(facebookCompletion:) withObject:resultNum waitUntilDone:NO];
        };
        [self shareTo:SLServiceTypeFacebook via:sender completion:completionHandler
          failureMessage:NSLocalizedString(@"You have not setup a Facebook account. "
            "Please add an account to the Facebook settings in the Settings app.", nil)];
    }
}

- (void)twitterCompletion:(NSNumber*)result {
    switch (result.intValue) {
    case SLComposeViewControllerResultCancelled:
        [TRStatistics checkpoint:TRCheckpointCancelledShareTwitter];
        break;
    case SLComposeViewControllerResultDone:
        [self didShareViaButton:self.twitterButton];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            _currentlySavingRecipe = YES;
            [self.popoverDelegate dismissOpenPopover];
        }
        [PTGNotify displayMessage:NSLocalizedString(@"Shared to Twitter", nil) aboveViewController:self withCompletionBlock:^(void){[self.popoverDelegate reopenLastPopover];}];
        break;
    }
}

#if 1   // geofftest
- (IBAction)doShareTwitter:(id)sender {
    if ([self spinForCurrentLargeThenRetry:sender] == kCurrentLargeWaiting)
        return;

    if (self.twitterButton.isEnabled) {
        [self saveImageAndRecipe];
        SLComposeViewControllerCompletionHandler completionHandler = ^(SLComposeViewControllerResult result){
            NSNumber *resultNum = [NSNumber numberWithInt:result];
            [self performSelectorOnMainThread:@selector(twitterCompletion:) withObject:resultNum waitUntilDone:NO];
        };
        [self shareTo:SLServiceTypeTwitter via:sender completion:completionHandler
          failureMessage:NSLocalizedString(@"You have not setup a Twitter account. "
            "Please add an account to the Twitter settings in the Settings app.", nil)];
    }
}
#else
- (IBAction)doShareTwitter:(id)sender {
    NSString *text = @"My mail text";
    NSURL *recipients = [NSURL URLWithString:@"mailto:email@domain.com?subject=An%20awesome%20subject%20line"];
    NSArray *activityItems = @[text, recipients];
    UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
    activityController.excludedActivityTypes = @[UIActivityTypePostToFacebook
                                                 , UIActivityTypePostToTwitter
                                                 , UIActivityTypePostToWeibo
                                                 , UIActivityTypeMessage
//                                                 , UIActivityTypeMail
                                                 , UIActivityTypePrint
                                                 , UIActivityTypeCopyToPasteboard
                                                 , UIActivityTypeAssignToContact
                                                 , UIActivityTypeSaveToCameraRoll
                                                 , UIActivityTypeAddToReadingList
                                                 , UIActivityTypePostToFlickr
                                                 , UIActivityTypePostToVimeo
                                                 , UIActivityTypePostToTencentWeibo
                                                 , UIActivityTypeAirDrop];
    
    [self presentViewController:activityController animated:YES completion:nil];
    

}
#endif

- (IBAction)doShareMail:(id)sender {
    NSString *text = @"My mail text";
    NSURL *recipients = [NSURL URLWithString:@"mailto:email@domain.com?subject=An%20awesome%20subject%20line"];
    NSArray *activityItems = @[text, recipients];
    UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
    [self presentViewController:activityController animated:YES completion:nil];
}

- (IBAction)doShareIM:(id)sender {
    
}

- (IBAction)doShareFlickr:(id)sender {
    
}

- (IBAction)doShareAirDrop:(id)sender {
    
}

- (IBAction)doShareGooglePlus:(id)sender {
}

- (IBAction)doSharePinterest:(id)sender {
}

#pragma mark - SaveRecipeViewControllerDelegate

- (void)saveRecipeViewControllerDoCancel:(SaveRecipeViewController *)controller {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        UINavigationController *navCon = [self navigationController];
        [navCon popViewControllerAnimated:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:NULL];
    }
}

- (void)saveRecipeViewControllerDoSave:(SaveRecipeViewController *)controller withRecipeName:(NSString *)recipeName {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        UINavigationController *navCon = [self navigationController];
        [navCon popViewControllerAnimated:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:NULL];
    }
    [self.dataController saveRecipeUsingName:recipeName];
    [self.dataController updateMagicWeights];
    [self.dataController resetAllRecipesInAllFolders];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationResetStyletSections
                                                        object:self userInfo:nil];
    [self.saveRecipeButton setSelected:YES];
}

#pragma mark - UIDocumentInteractionControllerDelegate

- (void)documentInteractionController:(UIDocumentInteractionController*)controller
           didEndSendingToApplication:(NSString*)application {
    PTGButton* reason = documentInteractionControllerReason;
    [self didShareViaButton:reason];
}

@end
