//
//  ToolViewController.h
//  RadLab
//
//  Created by Geoff Scott on 3/4/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CropOverlayView.h"
#import "ImageDataController.h"
#import "PTGSlider.h"

@protocol ToolViewControllerDelegate;

@interface ToolViewController : UIViewController <CropOverlayViewDelegate>

@property (weak, nonatomic) id<ToolViewControllerDelegate> delegate;
@property (weak, nonatomic) ImageDataController *dataController;
@property (weak, nonatomic) IBOutlet CropOverlayView *cropOverlay;
@property (weak, nonatomic) IBOutlet UIView *cropDisplay;
@property (weak, nonatomic) IBOutlet UIView *controlBar;
@property (weak, nonatomic) IBOutlet UIView *optionBar;
@property (weak, nonatomic) IBOutlet UIView *toolBar;
@property (weak, nonatomic) IBOutlet PTGSlider *currentSlider;
@property (weak, nonatomic) IBOutlet UIImageView *titleView;
@property (weak, nonatomic) IBOutlet UIButton *cropTool;
@property (weak, nonatomic) IBOutlet UIButton *rotateTool;
@property (weak, nonatomic) IBOutlet UIScrollView *optionsScrollView;

- (IBAction)doApply:(id)sender;
- (IBAction)doCancel:(id)sender;
- (IBAction)doResetEverything:(id)sender;
- (IBAction)toggleAutoDisplay:(id)sender;
- (IBAction)doShowCrop:(id)sender;
- (IBAction)doShowRotate:(id)sender;
- (IBAction)doShowPerspective:(id)sender;

- (IBAction)doFlipHorizontal:(id)sender;
- (IBAction)doFlipVertical:(id)sender;
- (IBAction)doRotate90Right:(id)sender;
- (IBAction)doRotate90Left:(id)sender;
- (IBAction)doRotateSliderStarted:(PTGSlider *)sender;
- (IBAction)doRotateSliderValueChanged:(PTGSlider *)sender;
- (IBAction)doRotateSliderStopped:(PTGSlider *)sender;
- (IBAction)doRotateSliderTouch:(PTGSlider *)sender;

- (IBAction)doAspectSixteenNine:(id)sender;
- (IBAction)doAspectSevenFive:(id)sender;
- (IBAction)doAspectThreeTwo:(id)sender;
- (IBAction)doAspectFourThree:(id)sender;
- (IBAction)doAspectFiveFour:(id)sender;
- (IBAction)doAspectOneOne:(id)sender;
- (IBAction)doAspectFourFive:(id)sender;
- (IBAction)doAspectThreeFour:(id)sender;
- (IBAction)doAspectTwoThree:(id)sender;
- (IBAction)doAspectFiveSeven:(id)sender;
- (IBAction)doAspectNineSixteen:(id)sender;
- (IBAction)doCropSliderStarted:(PTGSlider *)sender;
- (IBAction)doCropSliderValueChanged:(PTGSlider *)sender;
- (IBAction)doCropSliderStopped:(PTGSlider *)sender;
- (IBAction)doCropSliderTouch:(PTGSlider *)sender;

@end

@protocol ToolViewControllerDelegate <NSObject>

- (void)doCloseToolView:(ToolViewController *)controller;

@end