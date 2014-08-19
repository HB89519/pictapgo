//
//  WorkspaceViewController.h
//  RadLab
//
//  Created by Geoff Scott on 7/15/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TapEditViewController.h"
#import "MKStoreManager.h"

@protocol WorkspaceViewPopoverDelegate <NSObject>

- (void)refresh;
- (void)dismissOpenPopover;
- (void)reopenLastPopover;
- (void)showHelpScreen:(NSString*)urlString;

@optional
// for a viewcontroller, these already exist, but the client(?) needs to know about them explicitly
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion;
- (void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion;

@end

@interface WorkspaceViewController : TapEditViewController <UIPopoverControllerDelegate,
                                                            WorkspaceViewPopoverDelegate, MKStoreManagerDelegate>

@property (weak, nonatomic) IBOutlet UIButton *picButton;
@property (weak, nonatomic) IBOutlet UIButton *aboutButton;
@property (weak, nonatomic) IBOutlet UIButton *goButton;

- (IBAction)doShowGo:(id)sender;
- (IBAction)doShowPic:(id)sender;
- (IBAction)doShowAbout:(id)sender;

- (void)refreshImages:(BOOL)bSetAfterImage;

@end
