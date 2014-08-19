//
//  AppDelegate.m
//  RadLab
//
//  Created by Geoff Scott on 10/29/12.
//  Copyright (c) 2012 Totally Rad. All rights reserved.
//

#import "AppDelegate.h"

#import "Appirater.h"
#import "AppSettings.h"
#import "ChooseImageViewController.h"
#import "EditGridViewController.h"
#import "TRFileLogFormatter.h"
#import "ImageDataController.h"
#import "PTGNotify.h"
#import "TRImageProvider.h"
#import "TRHelper.h"
#import "TRStatistics.h"
#import "UIDevice-Hardware.h"
#import "WorkspaceViewController.h"
#import "MemoryStatistics.h"
#import "MKStoreManager.h"

#import "DDASLLogger.h"
#import "DDTTYLogger.h"
#import "DDFileLogger.h"

#ifdef USE_HOCKEYAPP
  #import <HockeySDK/HockeySDK.h>

#endif

#ifdef USE_FACEBOOKINTEGRATION
  #import "TRFacebookIntegration.h"
#endif

#ifdef USE_APPIRATER
@interface AppDelegate () <AppiraterDelegate>
@end
#endif

#ifdef USE_HOCKEYAPP
@interface AppDelegate (HockeyProtocols)
  <BITHockeyManagerDelegate, BITUpdateManagerDelegate, BITCrashManagerDelegate>
@end
#endif

@interface AppDelegate () <UIAlertViewDelegate> {
    DDFileLogger* fileLogger;
}
@end

static const int ddLogLevel = LOG_LEVEL_INFO;
static const NSInteger emailRequestAlertTag = 0xe3a1l;
static const NSInteger confirmCrashTag = 0xc2a54;

@implementation AppDelegate

@synthesize dataController = _dataController;

- (BOOL)openImageInEditor:(id<TRImageProvider>)imageProvider {
    [self.dataController setImageProvider:imageProvider];

    UINavigationController *navigationController = (UINavigationController *)self.window.rootViewController;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        WorkspaceViewController *workspace = (WorkspaceViewController *)[[navigationController viewControllers] objectAtIndex:0];
        [workspace refreshImages:YES];
        [workspace dismissOpenPopover];
    } else {
        [navigationController popToRootViewControllerAnimated:NO];
        [navigationController.topViewController performSegueWithIdentifier:@"showEditorGrid" sender:self];

        DDLogVerbose(@"performed showEditorGrid segue");
    }
    
    return YES;
}

- (void)handleCrash {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        DDLogError(@"handleCrash -- can't do crash-recovery on iPad :-(");
        return;
    }

    DDLogError(@"handleCrash -- segue directly to Share screen");

    UIAlertView* confirmCrash = [[UIAlertView alloc] initWithTitle:@"Crash Recovery"
      message:@"Sorry! PicTapGo appears to have\ncrashed on the previous run.\nWould you like to try to recover?"
      delegate:self cancelButtonTitle:@"Ignore crash" otherButtonTitles:@"Recover", nil];
    confirmCrash.tag = confirmCrashTag;
    [confirmCrash show];
}

#ifdef USE_HOCKEYAPP
- (void)setupHockeyApp {
    NSBundle* mainBundle = [NSBundle mainBundle];
    NSString* betaID = [mainBundle objectForInfoDictionaryKey:@"HockeyAppBetaID"];
    NSString* liveID = [mainBundle objectForInfoDictionaryKey:@"HockeyAppLiveID"];
    BITHockeyManager* mgr = [BITHockeyManager sharedHockeyManager];
    [mgr configureWithBetaIdentifier:betaID liveIdentifier:liveID delegate:self];
    mgr.crashManager.showAlwaysButton = YES;
    [mgr startManager];
    if (mgr.crashManager.didCrashInLastSession)
        [TRStatistics crashedOnPreviousRun];
}
#else
# if defined(CONFIGURATION_AppStore) || defined(CONFIGURATION_Alpha)
#  error Building for App Store without HockeyApp enabled
# endif
#endif

#ifdef USE_APPIRATER
typedef enum { HARDWARE_SLOW, HARDWARE_MEDIUM, HARDWARE_FAST } HardwareSpeed;

- (HardwareSpeed)hardwareSpeed {
    NSString* specificModel = [[UIDevice currentDevice] platform];
    if ([specificModel hasPrefix:@"iPhone"]) {
        static NSString* const k4SModelString = @"iPhone4,1";
        NSComparisonResult cmp = [specificModel compare:k4SModelString];
        if (cmp > 0) {
            // iPhone 5 and better
            return HARDWARE_FAST;
        } else if (cmp == 0) {
            // iPhone 4S
            return HARDWARE_MEDIUM;
        } else {
            // iPhone 4 and earlier
            return HARDWARE_SLOW;
        }
    } else if ([specificModel hasPrefix:@"iPad"]) {
        // iPads
        return HARDWARE_MEDIUM;
    } else {
        // iPods, etc.
        return HARDWARE_SLOW;
    }
}
- (void)setupAppirater {
    // uncomment to reset "already rated"
    //[[NSUserDefaults standardUserDefaults] setBool:NO forKey:kAppiraterRatedCurrentVersion];

    NSString* appStoreId = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"AppStoreID"];
    if (!appStoreId || appStoreId.length == 0) {
        DDLogError(@"");
        DDLogError(@"************************************************");
        DDLogError(@"****** No AppStoreID found in Info.plist! ******");
        DDLogError(@"***** Fix this before release to App Store *****");
        DDLogError(@"************************************************");
        DDLogError(@"");
        return;
    }

    // TODO: consider checking [TRStatistics crashCount] here

    HardwareSpeed speed = [self hardwareSpeed];

    [Appirater setDelegate:self];
    [Appirater setAppId:appStoreId];
    [Appirater setTimeBeforeReminding:7];

    // ALL of the following conditions must be met for the dialog to be shown
    switch (speed) {
    case HARDWARE_SLOW:
        [Appirater setDaysUntilPrompt:9999];
        break;
    case HARDWARE_MEDIUM:
        [Appirater setDaysUntilPrompt:0];
        [Appirater setUsesUntilPrompt:0];
        [Appirater setSignificantEventsUntilPrompt:12];
        break;
    case HARDWARE_FAST:
        [Appirater setDaysUntilPrompt:0];
        [Appirater setUsesUntilPrompt:0];
        [Appirater setSignificantEventsUntilPrompt:8];
        break;
    }

    // change this line (temporarily!) if you want to enable Appirater debugging
    [Appirater setDebug:NO];

  #if defined(CONFIGURATION_Alpha) || defined(CONFIGURATION_AppStore)
    // Belt AND suspenders: make doubly sure we don't turn on Appirater
    // in debug mode for distributed builds.
    [Appirater setDebug:NO];    // DON'T CHANGE THIS LINE!!
  #endif
}
#endif

#undef AGGRESSIVELY_SIMULATE_MEMORY_WARNINGS

#ifdef AGGRESSIVELY_SIMULATE_MEMORY_WARNINGS
- (void)simulateMemoryWarning {
    //[[NSNotificationCenter defaultCenter]
      //postNotificationName:UIApplicationDidReceiveMemoryWarningNotification
      //object:[UIApplication sharedApplication];
    SEL memoryWarningSel = @selector(_performMemoryWarning);
    if ([[UIApplication sharedApplication] respondsToSelector:memoryWarningSel]) {
      #pragma clang diagnostic push
      #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [[UIApplication sharedApplication] performSelector:memoryWarningSel];
      #pragma clang diagnostic pop
    } else {
        DDLogError(@"Whoops UIApplication no longer responds to -_performMemoryWarning");
    }
}
#endif

- (void)setupLumberjack {
  #ifndef CONFIGURATION_AppStore
    [[DDTTYLogger sharedInstance] setLogFormatter:[[TRFileLogFormatter alloc] init]];
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
  #endif

    [[DDASLLogger sharedInstance] setLogFormatter:[[TRFileLogFormatter alloc] init]];
    [DDLog addLogger:[DDASLLogger sharedInstance]];

    fileLogger = [[DDFileLogger alloc] init];
    fileLogger.logFormatter = [[TRFileLogFormatter alloc] init];
    fileLogger.rollingFrequency = 24 * 60 * 60; // 24-hour rolling
    fileLogger.logFileManager.maximumNumberOfLogFiles = 7;
    [DDLog addLogger:fileLogger];
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication*)application {
    DDLogWarn(@"APPLICATION RECEIVED MEMORY WARNING");
    [DDLog flushLog];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    
    // This MUST be done first (otherwise we can't see diagnostic log messages)
    [self setupLumberjack];

  #ifdef USE_UDID_FOR_BUG_TRACKER
    DDLogError(@"************* Bug Tracker using UDIDs!!! **************");
  #endif
    DDLogError(@"TR device id %@", [[TRStatistics deviceIdentifier] UUIDString]);

  #ifdef USE_HOCKEYAPP
    [self setupHockeyApp];
  #endif

  #ifdef AGGRESSIVELY_SIMULATE_MEMORY_WARNINGS
    DDLogWarn(@"******* AGGRESSIVELY SIMULATING MEMORY WARNINGS ********");
    [NSTimer scheduledTimerWithTimeInterval:2.0 target:self
      selector:@selector(simulateMemoryWarning) userInfo:nil repeats:YES];
  #endif
    
    [MKStoreManager loadPurchases];

    [AppSettings setup];

    [TRStatistics prepopulate];
    [TRStatistics ping];

    self.dataController = [[ImageDataController alloc] init];
    
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationNone];
    UINavigationController *navigationController = (UINavigationController *)self.window.rootViewController;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.dataController setEmptyImageProvider];
        WorkspaceViewController *workspace = (WorkspaceViewController *)[[navigationController viewControllers] objectAtIndex:0];
        [workspace setDataController:self.dataController];
    } else {
        ChooseImageViewController *chooseController = (ChooseImageViewController *)[[navigationController viewControllers] objectAtIndex:0];
        [chooseController setDataController:self.dataController];
    }

    BOOL appiraterAllowShow = YES;
    if ([self.dataController crashedOnPreviousRun]) {
        [self performSelector:@selector(handleCrash) withObject:nil afterDelay:0.5];
        appiraterAllowShow = NO;
    } else {
        [self.dataController ignorePreviousCrash];
    }

  #ifdef USE_APPIRATER
    [self setupAppirater];
    [self performSelector:@selector(showAppirater:) withObject:[NSNumber numberWithBool:appiraterAllowShow] afterDelay:0.5];
  #endif

    return YES;
}

- (void)showAppirater:(NSNumber*)allowShow {
    [Appirater appLaunched:allowShow.boolValue];
}

- (void)applicationDidBecomeActive:(UIApplication*)application {
    DDLogInfo(@">>> Application did become active (mem %@)", stringWithMemoryInfo());
#ifdef USE_FACEBOOKINTEGRATION
    [TRFacebookIntegration notifyAppStarted];
#endif
    [TRHelper unblockCoreImageUsage];
}

- (void)applicationWillResignActive:(UIApplication*)application {
    DDLogInfo(@">>> Application will resign active (mem %@)", stringWithMemoryInfo());
    [TRHelper blockCoreImageUsage];
}

- (void)applicationDidEnterBackground:(UIApplication*)application {
    DDLogInfo(@">>> Application did enter background");
    [AppSettings synchronize];
    [DDLog flushLog];
}

- (void)applicationWillEnterForeground:(UIApplication*)application {
    DDLogInfo(@">>> Application will enter foreground (mem %@)", stringWithMemoryInfo());
  #ifdef USE_APPIRATER
    [Appirater appEnteredForeground:NO];
  #endif
}

- (void)setDataController:(ImageDataController *)dataController {
    _dataController = dataController;
}

- (BOOL)application:(UIApplication*)application openURL:(NSURL*)url
  sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    DDLogInfo(@"application openURL(%@):sourceApplication(%@):annotation(%@)",
      url, sourceApplication, annotation);

    if ([url.scheme isEqual:@"file"]) {
        NSURLRequest* req = [NSURLRequest requestWithURL:url];

        // Because the URL scheme is "file" we already know the resource is on
        // the local device, so running the request synchronously should be fine.
        NSURLResponse* rsp = nil;
        NSError* err = nil;
        NSData* data = [NSURLConnection sendSynchronousRequest:req returningResponse:&rsp error:&err];

        if (!err) {
            DDLogInfo(@"url rsp=%@ mime=%@ datalen=%zd", rsp, [rsp MIMEType], [data length]);
            if ([rsp.MIMEType isEqual:@"image/jpeg"] || [rsp.MIMEType isEqual:@"image/png"]) {
                TREncodedImageProvider* imageProvider =
                  [[TREncodedImageProvider alloc] initWithData:data];
                if (imageProvider)
                    return [self openImageInEditor:imageProvider];
            } else if ([rsp.MIMEType isEqual:@"text/plain"]) {
                if ([[rsp.suggestedFilename pathExtension] isEqual:@"pictapgo-recipe-batch"]) {
                    NSString* recipeBatch = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    [self.dataController importRecipeBatch:recipeBatch];
                    return YES;
                }
            }
        }
    } else if ([url.scheme isEqualToString:@"pictapgo"]) {
        if ([url.host isEqualToString:@"r"]) {
            NSString* recipeName = [self.dataController importRecipeFromURL:url];

            UINavigationController *navigationController = (UINavigationController *)self.window.rootViewController;
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                WorkspaceViewController *workspace = (WorkspaceViewController *)[[navigationController viewControllers] objectAtIndex:0];
                [workspace refresh];
            }

            NSString* message = nil;
            if (recipeName) {
                message = [[NSLocalizedString(@"Imported recipe", nil) stringByAppendingString:@"\n"] stringByAppendingString:recipeName];
            } else {
                message = NSLocalizedString(@"Sorry!\nSomething wrong\nwith Recipe.\nCouldn't import it!", nil);
            }

            [PTGNotify displayMessage:message aboveViewController:navigationController.topViewController forDuration:2.0f];
        } else {
            DDLogError(@"invalid pictapgo url: %@", url);
        }
    }
    
    return NO;
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView*)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == confirmCrashTag) {
        if (buttonIndex == alertView.cancelButtonIndex) {
            [self.dataController ignorePreviousCrash];
        } else {
            if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
                UINavigationController* navCon = (UINavigationController*)self.window.rootViewController;
                [navCon popToRootViewControllerAnimated:NO];
                [navCon.topViewController performSegueWithIdentifier:@"showShare" sender:self];
            }
        }
    } else if (alertView.tag == emailRequestAlertTag) {
        UITextField* field = [alertView textFieldAtIndex:0];
        if (buttonIndex == alertView.cancelButtonIndex) {
            DDLogInfo(@"email refused");
        } else if (field.text.length < 5) {
            DDLogInfo(@"insane email provided: %@", field.text);
        } else {
            [TRStatistics setUserEmailAddress:field.text];
        }
    }
}

#pragma mark - AppiraterDelegate

- (void)appiraterDidDisplayAlert:(Appirater *)appirater {
    DDLogInfo(@"Appirater: displayed alert");
}

- (void)appiraterDidDeclineToRate:(Appirater*)appirater {
    DDLogInfo(@"Appirater: declined to rate");
}

- (void)appiraterDidOptToRate:(Appirater *)appirater {
    DDLogInfo(@"Appirater: opted to rate");
}

- (void)appiraterDidOptToRemindLater:(Appirater *)appirater {
    DDLogInfo(@"Appirater: opted to remind later");
}

#ifdef USE_HOCKEYAPP

- (void)attemptToAcquireEmailAddress {
    NSString* email = [TRStatistics userEmailAddress];
    if (email)
        return;
    
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Optional Contact Info", nil)
      message:NSLocalizedString(@"May we contact you to help fix this?", nil) delegate:self
      cancelButtonTitle:NSLocalizedString(@"No", nil) otherButtonTitles:NSLocalizedString(@"OK", nil), nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    alert.tag = emailRequestAlertTag;
    UITextField* field = [alert textFieldAtIndex:0];
    field.placeholder = NSLocalizedString(@"E-mail (optional)", nil);
    field.keyboardType = UIKeyboardTypeEmailAddress;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    [alert show];
}

#pragma mark - BITUpdateManagerDelegate

- (NSString*)customDeviceIdentifier {
  #ifdef USE_UDID_FOR_BUG_TRACKER
    #ifdef CONFIGURATION_AppStore
      #error UDID usage not allowed in App Store
    #endif
    // Set UDID for TestFlight.  This API is deprecated by Apple as of iOS5.
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [[UIDevice currentDevice] uniqueIdentifier];
    #pragma clang diagnostic pop
  #endif

    return [[TRStatistics deviceIdentifier] UUIDString];
}

- (NSString*)customDeviceIdentifierForUpdateManager:(BITUpdateManager*)updateManager {
    return [self customDeviceIdentifier];
}

#pragma mark - BITCrashManagerDelegate

- (NSString*)getLogFileContentsWithMaxSize:(NSInteger)maxSize {
    NSMutableString* result = [NSMutableString string];
    NSArray* sortedLogFileInfos = fileLogger.logFileManager.sortedLogFileInfos;
    for (DDLogFileInfo* info in sortedLogFileInfos) {
        NSData* data = [[NSFileManager defaultManager] contentsAtPath:info.filePath];
        if (data.length > 0) {
            NSMutableString* r = [[NSMutableString alloc] initWithBytes:data.bytes
              length:data.length encoding:NSUTF8StringEncoding];
            [r appendString:result];
            result = r;
            if (result.length > maxSize)
                break;
        }
    }
    if (result.length > maxSize)
        return [result substringWithRange:NSMakeRange(result.length - maxSize - 1, maxSize)];
    return result;
}

- (NSString*)applicationLogForCrashManager:(BITCrashManager*)crashManager {
    NSString* description = [self getLogFileContentsWithMaxSize:30000];
    return (description.length == 0) ? nil : description;
}

- (void)crashManagerWillSendCrashReport:(BITCrashManager*)crashManager {
    [self attemptToAcquireEmailAddress];
}

#pragma mark - BITHockeyManagerDelegate

- (NSString*)userIDForHockeyManager:(BITHockeyManager*)hockeyManager
  componentManager:(BITHockeyBaseManager*)componentManager {
    return [self customDeviceIdentifier];
}

- (NSString*)userEmailForHockeyManager:(BITHockeyManager*)hockeyManager componentManager:(BITHockeyBaseManager*)componentManager {
    return [TRStatistics userEmailAddress];
}

#endif

@end

