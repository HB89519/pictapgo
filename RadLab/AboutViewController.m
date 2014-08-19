//
//  AboutViewController.m
//  RadLab
//
//  Created by Geoff Scott on 12/18/12.
//  Copyright (c) 2012 Totally Rad. All rights reserved.
//

#import "AboutViewController.h"
#import "AppSettings.h"
#import "EditGridViewController.h"
#import "UICommon.h"
#import "PTGNotify.h"

@implementation AboutViewNavigation
@synthesize section = _section;
@synthesize url = _url;
+ (AboutViewNavigation*)newHelpURL:(NSString*)urlString {
    AboutViewNavigation* nav = [[AboutViewNavigation alloc]
      initWithSection:kContentViewIDHelp url:[NSURL URLWithString:urlString]];
    return nav;
}
- (AboutViewNavigation*)initWithSection:(NSInteger)section url:(NSURL*)url {
    self = [super init];
    if (self) {
        self.section = section;
        self.url = url;
    }
    return self;
}
- (NSString*)description {
    return [NSString stringWithFormat:@"%zd %@", self.section, self.url];
}
@end

@interface AboutViewController () <UIActionSheetDelegate, UIWebViewDelegate>

@property (nonatomic, retain) UIView *displayedContentView;
@property (nonatomic, retain) NSString* navFragment;

@end

static const int ddLogLevel = LOG_LEVEL_VERBOSE;

@implementation AboutViewController

@synthesize delegate = _delegate;
@synthesize dataController = _dataController;
@synthesize toolBar = _toolBar;
@synthesize contentView = _contentView;
@synthesize displayedContentView = _displayedContentView;
@synthesize creditsView = _creditsView;
@synthesize helpWebView = _helpWebView;
@synthesize aboutButton = _aboutButton;
@synthesize helpButton= _helpButton;
@synthesize settingsButton = _settingsButton;
@synthesize navigation = _navigation;
@synthesize stressTestButton = _stressTestButton;
@ synthesize backgroundSwitch = _backgroundSwitch;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    BOOL enableStressTest = YES;
  #ifdef CONFIGURATION_AppStore
    enableStressTest = NO;
  #endif

    [self.stressTestButton setEnabled:enableStressTest];
    [self.stressTestButton setHidden:!enableStressTest];
}

- (void)viewDidUnload {
    self.displayedContentView = nil;
    
    [super viewDidUnload];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    addMaskToToolBar(self.toolBar);
    if (self.navigation) {
        AboutViewNavigation* nav = self.navigation;
        self.navigation = nil;
        [self setDisplayedContent:nav.section url:nav.url];
    } else {
        [self setDisplayedContent:kContentViewIDSettings];
    }
}

- (void) updateSettingsDisplay {
    [self.backgroundSwitch setOn:AppSettings.manager.useSimpleBackground animated:NO];
}

- (void)updateCreditsDisplay {
    NSError *error;
    NSString *creditsFilePath = [[NSBundle mainBundle] pathForResource:@"Credits" ofType: @"txt"];
    NSString *creditsText = [NSString stringWithContentsOfFile:creditsFilePath encoding:NSUTF8StringEncoding error: &error];
    if (error)
        DDLogError(@"Error opening Credits.txt file: %@", error);
    
    // add in the runtime information
    NSString *versionStr = [NSString stringWithFormat:@"%@", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]];
    NSString *buildStr = [NSString stringWithFormat:@"%@", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]];
    NSString *displayText = [NSString stringWithFormat:creditsText, versionStr, buildStr];
    
    [self.creditsView setText:displayText];
}

#define USE_LOCAL_HELP 1

- (void)updateHelpDisplay:(NSURL*)url {
  #if USE_LOCAL_HELP
    NSURL* helpFileURL = [[NSBundle mainBundle] URLForResource:@"help/index" withExtension:@"html"];
    NSURL* baseURL = [helpFileURL URLByDeletingLastPathComponent];
  #else
    // for development of the Help content - not for release builds to Apple
    NSURL* baseURL = [NSURL URLWithString:@"http://www.pictapgo.com/help_test/"];
  #endif

    if (!url)
        url = [NSURL URLWithString:@"index.html"];
    NSURL* helpURL = [NSURL URLWithString:url.path relativeToURL:baseURL];
    NSURLRequest *request = [NSURLRequest requestWithURL:helpURL];
    self.navFragment = url.fragment;
    self.helpWebView.delegate = self;
    [self.helpWebView loadRequest:request];
}

- (void)setDisplayedContent:(NSInteger)contentID {
    [self setDisplayedContent:contentID url:nil];
}

- (void)setDisplayedContent:(NSInteger)contentID url:(NSURL*)url {
    NSArray *nibContents = nil;
    
    switch (contentID) {
        case kContentViewIDHelp:
            nibContents = [[NSBundle mainBundle] loadNibNamed:@"Content_Help" owner:self options:nil];
            [self updateHelpDisplay:url];
            break;
            
        case kContentViewIDSettings:
            nibContents = [[NSBundle mainBundle] loadNibNamed:@"Content_Settings" owner:self options:nil];
            [self updateSettingsDisplay];
            break;
            
        case kContentViewIDAbout:
            nibContents = [[NSBundle mainBundle] loadNibNamed:@"Content_Credits" owner:self options:nil];
            [self updateCreditsDisplay];
            break;
            
        default:
            break;
    }
    
    if (nibContents) {
        [self.displayedContentView removeFromSuperview];
        
        self.displayedContentView = [nibContents objectAtIndex:0];
        [self.view addSubview:self.displayedContentView];
        [self.view sendSubviewToBack:self.displayedContentView];
        [self.displayedContentView setFrame:self.contentView.frame];
        
        [self.aboutButton setSelected:(contentID == kContentViewIDAbout)];
        [self.helpButton setSelected:(contentID == kContentViewIDHelp)];
        [self.settingsButton setSelected:(contentID == kContentViewIDSettings)];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)doBack:(id)sender {
    [self.delegate doCloseAboutView:self];
}

- (IBAction)doShowAbout:(id)sender {
    [self setDisplayedContent:kContentViewIDAbout];
}

- (IBAction)doShowHelp:(id)sender {
    [self setDisplayedContent:kContentViewIDHelp];
}

- (IBAction)doShowSettings:(id)sender {
    [self setDisplayedContent:kContentViewIDSettings];
}

- (void)confirmSheet:(NSString*)question tag:(NSInteger)tag {
    UIActionSheet *confirmSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(question, nil)
                                                              delegate:self
                                                     cancelButtonTitle:NSLocalizedString(@"No", nil)
                                                destructiveButtonTitle:NSLocalizedString(@"Yes", nil)
                                                     otherButtonTitles:nil];
    confirmSheet.tag = tag;
    [confirmSheet showInView:self.view];
}

enum ActionSheetQuestionID {
    kResetEverything = 1,
    kResetStyletList,
    kResetMagicFolder,
    kResetAllRecipes,
    kResetHelpMessages,
    kResetAllHistory
};

- (IBAction)doResetEverything:(id)sender {
    [self confirmSheet:NSLocalizedString(@"Reset Everything?", nil) tag:kResetEverything];
}

- (IBAction)doResetStyletList:(id)sender {
    [self confirmSheet:NSLocalizedString(@"Reset order of Filters?", nil) tag:kResetStyletList];
}

- (IBAction)doResetMagicFolder:(id)sender {
    [self confirmSheet:NSLocalizedString(@"Reset “My Style”?", nil) tag:kResetMagicFolder];
}

- (IBAction)doDeleteAllRecipes:(id)sender {
    [self confirmSheet:NSLocalizedString(@"Delete all Recipes?", nil) tag:kResetAllRecipes];
}

- (IBAction)doClearHistory:(id)sender {
    [self confirmSheet:NSLocalizedString(@"Clear all History?", nil) tag:kResetAllHistory];
}

- (IBAction)doResetHelpMessages:(id)sender {
    [self confirmSheet:NSLocalizedString(@"Reset displaying initial help messages?", nil) tag:kResetHelpMessages];
}

- (IBAction)doBackgroundSwitchChanged:(id)sender {
    AppSettings.manager.useSimpleBackground = [self.backgroundSwitch isOn];
}

- (IBAction)doStressTest:(id)sender {
    [self.dataController selfTest];
    [PTGNotify showSpinnerAboveViewController:self];
}

#pragma mark - UIAlertViewDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    DDLogInfo(@"tapped \"%@\" button", [actionSheet buttonTitleAtIndex:buttonIndex]);
    if (buttonIndex == actionSheet.destructiveButtonIndex) {
        BOOL bPostNotification = NO;
        switch (actionSheet.tag) {
        case kResetEverything:
            [self.dataController resetStyletList];
            [self.dataController resetMagic];
            [self.dataController deleteAllRecipes];
            [self.dataController deleteAllHistory];
            [self.dataController resetUnlockedFilters];
            [AppSettings resetToDefaults];
            bPostNotification = YES;
            break;
        case kResetStyletList:
            [self.dataController resetStyletList];
            break;
        case kResetMagicFolder:
            [self.dataController resetMagic];
            bPostNotification = YES;
            break;
        case kResetAllRecipes:
            [self.dataController deleteAllRecipes];
            bPostNotification = YES;
            break;
        case kResetHelpMessages:
            [AppSettings resetHelpToDefaults];
            break;
        case kResetAllHistory:
            [self.dataController deleteAllHistory];
            bPostNotification = YES;
            break;
        }
        if (bPostNotification) {
            [self.dataController resetAllRecipesInAllFolders];
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationResetStyletSections
                                                            object:self userInfo:nil];
        }
    }
}

#pragma mark - UIWebViewDelegate

- (void)webViewDidFinishLoad:(UIWebView*)webView {
    if (self.navFragment) {
        NSString* fragment = self.navFragment;
        self.navFragment = nil;
        [self.helpWebView stringByEvaluatingJavaScriptFromString:
          [NSString stringWithFormat:@"window.location.hash='#%@'", fragment]];
    }
}

@end
