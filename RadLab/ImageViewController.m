//
//  ImageViewController.m
//  RadLab
//
//  Created by Geoff Scott on 7/9/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import "ImageViewController.h"

#import <QuartzCore/QuartzCore.h>
#import "ShareViewController.h"
#import "UICommon.h"
#import "UIDevice-Hardware.h"

@interface ImageViewController ()
{
    NSNumber *_savedStrength;
    UILabel *_beforeLabel;
}

@property (nonatomic, strong) UIPopoverController *goViewPopover;
@property (nonatomic, weak) UIPopoverController *currentOpenPopover;

@end

typedef enum {
    kLongPressShowsOriginal,
    kLongPressShowsPrevious
} ImageLongPressBehavior;

@implementation ImageViewController

@synthesize goViewPopover = _goViewPopover;
@synthesize currentOpenPopover = _currentOpenPopover;

@synthesize dataController = _dataController;
@synthesize afterImageView = _afterImageView;
@synthesize beforeImageView = _beforeImageView;
@synthesize goButton = _goButton;
@synthesize toolsButton = _toolsButton;
@synthesize toolBar = _toolBar;
@synthesize strengthSlider = _strengthSlider;
@synthesize undoButton = _undoButton;
@synthesize redoButton = _redoButton;

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self.toolBar setHidden:YES];

    _savedStrength = [self.dataController currentStrength];
    [self.strengthSlider setEnabled:NO];
    [self.strengthSlider setMinimumValue:0.0];
    [self.strengthSlider setMaximumValue:100.0];
    [self.strengthSlider setDefaultValue:_savedStrength.floatValue];
    [self.strengthSlider setValue:_savedStrength.floatValue];

    [self.undoButton setDelegate:self];
    [self.undoButton setEnabled:NO];
    [self.redoButton setEnabled:NO];

    CGRect labelFrame = CGRectMake(0.0, 0.0, 80.0, 22.0);
    _beforeLabel = [[UILabel alloc] initWithFrame:labelFrame];
    [_beforeLabel setTextColor:[UIColor darkGrayColor]];
    [_beforeLabel setBackgroundColor:[UIColor whiteColor]];
    [_beforeLabel setTextAlignment:NSTextAlignmentCenter];
    [_beforeLabel setAlpha:0.7];
    _beforeLabel.layer.cornerRadius = 4.0;
    _beforeLabel.layer.masksToBounds = YES;

    ShareViewController *share = [[ShareViewController alloc] initWithNibName:@"Popover_Share" bundle:nil];
    [share setDataController:self.dataController];
    UINavigationController *navigator = [[UINavigationController alloc] initWithRootViewController:share];
    [navigator setToolbarHidden:YES];
    [navigator setNavigationBarHidden:YES];
    self.goViewPopover = [[UIPopoverController alloc] initWithContentViewController:navigator];
    self.goViewPopover.delegate = self;
}

- (void)viewWillAppear:(BOOL)animated {
    [self setAfterImageStrength:self.strengthSlider.value / 100.0];
    setPreviewStylingForView(self.beforeImageView);
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    addPinstripingToView(self.view);

    [self setAfterImageStrength:self.strengthSlider.value / 100.0];
    if ([self.dataController currentStepIndex] > 0) {
        [self.strengthSlider setEnabled:YES];
        [self.undoButton setEnabled:YES];
    } else {
        [self.strengthSlider setEnabled:NO];
        [self.undoButton setEnabled:NO];
    }

    [self.toolBar setHidden:NO];
    addMaskToToolBar(self.toolBar);
    setupSmileySlider(self.strengthSlider);
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"showTools"]) {
        ToolViewController *toolController = (ToolViewController *)[segue destinationViewController];
        [toolController setDelegate:self];
        [toolController setDataController:self.dataController];
    }
}

- (void)setAfterImageStrength:(float)strength {
    [self.afterImageView setAlpha:strength];
}

- (void) resetStrengthSlider {
    [self.strengthSlider setMinimumValue:0.0];
    [self.strengthSlider setMaximumValue:100.0];
    [self.strengthSlider setValue:100.0 animated:NO];
    [self.strengthSlider setEnabled:[self.dataController currentStepIndex]];
    [self setAfterImageStrength:1.0];
}

- (void)refreshImages {
    [self resetStrengthSlider];

    [self.beforeImageView setImage:[self.dataController previousPreview]];
    [self.afterImageView setImage:[self.dataController currentPreviewAtFullStrength]];

    [self.undoButton setEnabled:[self.dataController currentStepIndex]];
    [self.redoButton setEnabled:NO];
    
    [self.goButton setEnabled:![self.dataController hasEmptyMaster]];
    [self.toolsButton setEnabled:![self.dataController hasEmptyMaster]];
}

- (IBAction)handleShortPress:(UILongPressGestureRecognizer *)recognizer {
    BOOL bInsideImageView = NO;
    NSInteger behaviorPref;
    
    CGRect previewFrame = self.afterImageView.frame;
    CGRect leftFrame = previewFrame;
    leftFrame.size.width = previewFrame.size.width / 2;
    CGRect rightFrame = previewFrame;
    rightFrame.size.width = leftFrame.size.width;
    rightFrame.origin.x += rightFrame.size.width;
    
    NSUInteger numTouches = [recognizer numberOfTouches];
    for (NSUInteger i = 0; i < numTouches; ++i ) {
		CGPoint location = [recognizer locationOfTouch:i inView:self.view];
        if (CGRectContainsPoint(leftFrame, location)) {
            bInsideImageView = YES;
            behaviorPref = kLongPressShowsOriginal;
            break;
        } else if (CGRectContainsPoint(rightFrame, location)) {
            bInsideImageView = YES;
            behaviorPref = kLongPressShowsPrevious;
            break;
        }
    }
    
    if ([recognizer state] == UIGestureRecognizerStateBegan) {
        if (bInsideImageView) {
            NSString *displayStr = NSLocalizedString(@"Previous", nil);
            if ((numTouches > 1 && behaviorPref == kLongPressShowsPrevious)
                || (numTouches == 1 && behaviorPref == kLongPressShowsOriginal)) {
                [self.beforeImageView setImage:[self.dataController masterPreview]];
                displayStr = NSLocalizedString(@"Original", nil);
            }
            [self.afterImageView setHidden:YES];
            [self displayBeforeString:displayStr onSide:behaviorPref == kLongPressShowsOriginal];
        }
    } else if ([recognizer state] == UIGestureRecognizerStateEnded) {
        [self.afterImageView setHidden:NO];
        [self.beforeImageView setImage:[self.dataController previousPreview]];
        [self dismissBeforeString];
    }
}

- (void) displayBeforeString:(NSString *)message onSide:(BOOL)bLeftSide {
    CGRect previewFrame = self.afterImageView.frame;
    CGRect labelFrame = _beforeLabel.frame;
    
    if (bLeftSide) {
        labelFrame.origin.x = previewFrame.origin.x + 8.0;
    } else {
        labelFrame.origin.x = previewFrame.origin.x + previewFrame.size.width - 8 - labelFrame.size.width;
    }
    labelFrame.origin.y = previewFrame.origin.y + 4;
    
    [_beforeLabel setFrame:labelFrame];
    [_beforeLabel setText:message];
    [self.view addSubview:_beforeLabel];
}

- (void) dismissBeforeString {
    [_beforeLabel removeFromSuperview];
}

- (IBAction)doSliderValueChanged:(PTGSlider *)sender {
    [self setAfterImageStrength:sender.value / 100.0];
}

- (IBAction)doSliderStopped:(PTGSlider *)sender {
    NSNumber* val = [NSNumber numberWithFloat:sender.value];
    if (! [[self.dataController currentStrength] isEqualToNumber:val]) {
        [self.dataController setCurrentStrength:val];
    }
}

- (IBAction)doReset:(id)sender {
    if ([self.dataController currentStepIndex] != 0) {
        [self animateReset];
        
        [self.dataController resetRecipe];
        [self.strengthSlider setMinimumValue:0.0];
        [self.strengthSlider setMaximumValue:100.0];
        [self.strengthSlider setValue:100.0 animated:NO];
        [self.strengthSlider setEnabled:NO];
        [self.undoButton setEnabled:NO];
        [self.redoButton setEnabled:NO];
        [self refreshImages];
    }
}

- (IBAction)doUndo:(id)sender {
    if ([self.dataController undoAppliedStylet]) {
        [self animateUndoRedo:YES];
        
        // handled in animation
        // [self.afterImageView setImage:[self.dataController currentPreviewAtFullStrength]];
        [self.beforeImageView setImage:[self.dataController previousPreview]];
        float strength = 1.0;
        if ([self.dataController currentStepIndex] == 0) {
            [self.strengthSlider setEnabled:NO];
            [self.undoButton setEnabled:NO];
        } else {
            strength = [[self.dataController currentStrength] floatValue] / 100.0;
            [self.strengthSlider setEnabled:YES];
            [self.undoButton setEnabled:YES];
        }
        [self.redoButton setEnabled:YES];
        [self.strengthSlider setMinimumValue:0.0];
        [self.strengthSlider setMaximumValue:100.0];
        [self.strengthSlider setValue:[[self.dataController currentStrength] floatValue] animated:NO];
        [self setAfterImageStrength:strength];
    }
}

- (BOOL)currentlyAtLastStep {
    return ([self.dataController currentStepIndex] == [self.dataController appliedStepsCount] - 1);
}

- (IBAction)doRedo:(id)sender {
    if ([self.dataController redoAppliedStylet]) {
        [self animateUndoRedo:NO];
        
        // handled in animation
        // [self.afterImageView setImage:[self.dataController currentPreviewAtFullStrength]];
        [self.beforeImageView setImage:[self.dataController previousPreview]];
        [self.undoButton setEnabled:YES];
        self.redoButton.enabled = !self.currentlyAtLastStep;
        [self.strengthSlider setMinimumValue:0.0];
        [self.strengthSlider setMaximumValue:100.0];
        [self.strengthSlider setValue:[[self.dataController currentStrength] floatValue] animated:NO];
        [self.strengthSlider setEnabled:YES];
        float strength = [[self.dataController currentStrength] floatValue] / 100.0;
        [self setAfterImageStrength:strength];
    }
}

- (void) animateUndoRedo:(BOOL)direction {
    NSInteger dirMod = 1;
    if (!direction)
        dirMod = -1;
    
    CGRect origImageFrame = self.afterImageView.frame;
    float width = origImageFrame.size.width;
    float height = origImageFrame.size.height;
    
    UIImageView *movingImageView = [[UIImageView alloc] initWithFrame:CGRectMake(-width * dirMod, origImageFrame.origin.y, width, height)];
    [movingImageView setContentMode:UIViewContentModeScaleAspectFit];
    [movingImageView setImage:[self.dataController currentPreviewAtFullStrength]];
    setPreviewStylingForView(movingImageView);
    [self.view addSubview:movingImageView];
    
    // animate it all
    float duration = 0.25f;
    if ([[UIDevice currentDevice] platformType] == UIDevice4iPhone)
        duration = 0.4f;
    [UIView animateWithDuration:duration
                          delay:0.0f
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         [movingImageView setFrame:origImageFrame];
                     }
                     completion:^(BOOL finished){
                         if (finished) {
                             [self.afterImageView setImage:[self.dataController currentPreviewAtFullStrength]];
                             [movingImageView removeFromSuperview];
                         }
                     }];
}

- (void) animateReset {
// geofftest    [self animateFromGridCell:nil];
}

- (void)doShowPopover:(UIPopoverController *)controller fromFrame:(CGRect)sourceFrame {
    
    [self.currentOpenPopover dismissPopoverAnimated:YES];
    
    //	[controller presentPopoverFromRect:sourceFrame inView:self.view permittedArrowDirections:UIPopoverArrowDirectionDown animated:YES];
	[controller presentPopoverFromRect:sourceFrame inView:self.view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
    
    self.currentOpenPopover = controller;
}

- (IBAction)doShowGo:(id)sender {
    [self doShowPopover:self.goViewPopover fromFrame:self.goButton.frame];
}

#pragma mark -
#pragma mark UISplitViewDelegate

- (BOOL)splitViewController:(UISplitViewController *)svc
   shouldHideViewController:(UIViewController *)vc
              inOrientation:(UIInterfaceOrientation)orientation {
    // always show the other view
    return NO;
}

#pragma mark - ToolViewControllerDelegate

- (void)doCloseToolView:(ToolViewController *)controller {
    [self dismissViewControllerAnimated:YES completion:NULL];
    [self refreshImages];
    [self.dataController rebuildCurrentThumbnails];
}

#pragma mark - PTGButtonDelegate

- (void)PTGButtonDelegateLongPress:(PTGButton *)sourceButton {
    [self doReset:self];
}

@end
