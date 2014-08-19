//
//  ImageViewController.h
//  RadLab
//
//  Created by Geoff Scott on 7/9/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ImageDataController.h"
#import "PTGButton.h"
#import "PTGSlider.h"
#import "ToolViewController.h"

@interface ImageViewController : UIViewController <UISplitViewControllerDelegate,
                                                    UIPopoverControllerDelegate,
                                                    PTGButtonDelegate,
                                                    ToolViewControllerDelegate,
                                                    UIGestureRecognizerDelegate>

@property (weak, nonatomic) ImageDataController *dataController;
@property (weak, nonatomic) IBOutlet UIImageView *afterImageView;
@property (weak, nonatomic) IBOutlet UIImageView *beforeImageView;
@property (weak, nonatomic) IBOutlet UIButton *goButton;
@property (weak, nonatomic) IBOutlet UIButton *toolsButton;
@property (weak, nonatomic) IBOutlet UIView *toolBar;
@property (weak, nonatomic) IBOutlet PTGSlider *strengthSlider;
@property (weak, nonatomic) IBOutlet PTGButton *undoButton;
@property (weak, nonatomic) IBOutlet PTGButton *redoButton;

- (IBAction)handleShortPress:(UILongPressGestureRecognizer *)recognizer;

- (IBAction)doSliderValueChanged:(PTGSlider *)sender;
- (IBAction)doSliderStopped:(PTGSlider *)sender;
- (IBAction)doReset:(id)sender;
- (IBAction)doUndo:(id)sender;
- (IBAction)doRedo:(id)sender;
- (IBAction)doShowGo:(id)sender;

- (void)refreshImages;

@end
