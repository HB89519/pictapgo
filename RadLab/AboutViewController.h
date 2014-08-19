//
//  AboutViewController.h
//  RadLab
//
//  Created by Geoff Scott on 12/18/12.
//  Copyright (c) 2012 Totally Rad. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ImageDataController.h"

@protocol AboutViewControllerDelegate;

static const NSInteger kContentViewIDHelp = 0;
static const NSInteger kContentViewIDSettings = 1;
static const NSInteger kContentViewIDAbout = 2;

@interface AboutViewNavigation : NSObject
+ (AboutViewNavigation*)newHelpURL:(NSString*)urlString;
- (AboutViewNavigation*)initWithSection:(NSInteger)section url:(NSURL*)url;
@property NSInteger section;
@property NSURL* url;
@end

@interface AboutViewController : UIViewController

@property (weak, nonatomic) id<AboutViewControllerDelegate> delegate;
@property (weak, nonatomic) ImageDataController *dataController;
@property (weak, nonatomic) IBOutlet UIView *toolBar;
@property (weak, nonatomic) IBOutlet UIView *contentView;
@property (weak, nonatomic) IBOutlet UILabel *versionLabel;
@property (weak, nonatomic) IBOutlet UILabel *buildLabel;
@property (weak, nonatomic) IBOutlet UITextView *creditsView;
@property (weak, nonatomic) IBOutlet UIWebView *helpWebView;
@property (weak, nonatomic) IBOutlet UIButton *aboutButton;
@property (weak, nonatomic) IBOutlet UIButton *helpButton;
@property (weak, nonatomic) IBOutlet UIButton *settingsButton;
@property (weak, nonatomic) IBOutlet UIButton *stressTestButton;
@property (weak, nonatomic) IBOutlet UISwitch *backgroundSwitch;
@property AboutViewNavigation* navigation;

- (IBAction)doBack:(id)sender;
- (IBAction)doShowAbout:(id)sender;
- (IBAction)doShowHelp:(id)sender;
- (IBAction)doShowSettings:(id)sender;

- (IBAction)doResetEverything:(id)sender;
- (IBAction)doResetStyletList:(id)sender;
- (IBAction)doResetMagicFolder:(id)sender;
- (IBAction)doDeleteAllRecipes:(id)sender;
- (IBAction)doClearHistory:(id)sender;
- (IBAction)doResetHelpMessages:(id)sender;
- (IBAction)doBackgroundSwitchChanged:(id)sender;

- (IBAction)doStressTest:(id)sender;

@end

@protocol AboutViewControllerDelegate <NSObject>

- (void)doCloseAboutView:(AboutViewController *)controller;

@end