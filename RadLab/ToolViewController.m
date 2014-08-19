//
//  ToolViewController.m
//  RadLab
//
//  Created by Geoff Scott on 3/4/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import "ToolViewController.h"

#import "UICommon.h"

static int ddLogLevel = LOG_LEVEL_INFO;

@interface ToolViewController ()

@property (nonatomic, assign) NSInteger currentToolID;
@property (nonatomic, assign) float prevRotateSliderVal;
@property (nonatomic, assign) float maxAspectRatio;
@property (nonatomic, retain) UIView *displayedControlView;
@property (nonatomic, retain) UIView *displayedOptionView;

@end

static const NSInteger kToolIDCrop = 0;
static const NSInteger kToolIDRotate = 1;
static const NSInteger kToolIDPerspective = 2;
static const float kDefaultMaxAspectRatio = 2.0;

@implementation ToolViewController

// public
@synthesize delegate = _delegate;
@synthesize dataController = _dataController;
@synthesize cropOverlay = _cropOverlay;
@synthesize cropDisplay = _cropDisplay;
@synthesize controlBar = _controlBar;
@synthesize optionBar = _optionBar;
@synthesize toolBar = _toolBar;
@synthesize titleView = _titleView;
@synthesize cropTool = _cropTool;
@synthesize rotateTool = _rotateTool;

// private
@synthesize currentToolID = _currentToolID;
@synthesize prevRotateSliderVal = _prevRotateSliderVal;
@synthesize maxAspectRatio = _maxAspectRatio;
@synthesize displayedControlView = _displayedControlView;
@synthesize displayedOptionView = _displayedOptionView;

- (void)initCommon {
    self.currentToolID = kToolIDCrop;
    self.prevRotateSliderVal = 0.0;
    self.maxAspectRatio = kDefaultMaxAspectRatio;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        [self initCommon];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self initCommon];
    }
    return self;
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    UIImage *image = [self.dataController currentPreviewNoCrop];
    float imageAspectRatio = image.size.width / image.size.height;
    if (imageAspectRatio < 1.0)
        imageAspectRatio = 1/ imageAspectRatio;
    imageAspectRatio += 1.0;
    if (imageAspectRatio > self.maxAspectRatio)
        self.maxAspectRatio = imageAspectRatio;
    
    CropOverlayView *tempCropOverlay = [[CropOverlayView alloc] initWithFrame:self.cropDisplay.bounds];
    [self.cropDisplay addSubview:tempCropOverlay];
    self.cropOverlay = tempCropOverlay;
    [self.cropOverlay setDelegate:self];
    [self.cropOverlay setUpWithImage:image
                 andImageOrientation:self.dataController.cropImageOrientation
                    andCropTransform:self.dataController.cropTransform
                  andCropAspectRatio:self.dataController.cropAspectRatio];
    if (! CGSizeEqualToSize([self.cropOverlay getCropSourceImageSize], self.dataController.cropSourceImageSize)
        && ! CGSizeEqualToSize(self.dataController.cropSourceImageSize, CGSizeMake(0.0, 0.0))) {
        DDLogWarn(@"data controller cropSourceImageSize does not match size from the cropoverlayview");
    }

    [self.cropOverlay setBackgroundColor:[UIColor whiteColor]];
    UIView *tempMask = [[UIView alloc] initWithFrame:self.cropDisplay.frame];
    [tempMask setBackgroundColor:[UIColor blackColor]];
    [tempMask setAlpha:0.6];
    [tempMask setUserInteractionEnabled:NO];
    [self.view addSubview:tempMask];
    self.cropOverlay.maskView = tempMask;
    [self.cropOverlay displayCropCentered];
    [self.cropOverlay updateMask];
    
    [self setToolContent:kToolIDCrop];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [self.cropOverlay adjustToNewFrame:self.cropDisplay.frame];
}

- (float)calcRotationSliderValue {
    return radiansToDegrees(calcLimitedRotationValue([self.cropOverlay getRotationAngle], [self.cropOverlay getImageOrientation]));
}

- (void)setToolContent:(NSInteger)contentID {
    NSArray *controlContents = nil;
    NSArray *optionsContents = nil;
    float sliderVal = 0.0;

    switch (contentID) {
        case kToolIDCrop:
            controlContents = [[NSBundle mainBundle] loadNibNamed:@"Controls_Crop" owner:self options:nil];
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                optionsContents = [[NSBundle mainBundle] loadNibNamed:@"Options_AspectRatios" owner:self options:nil];
            } else {
                optionsContents = [[NSBundle mainBundle] loadNibNamed:@"Options_Crop" owner:self options:nil];
            }
            [self.titleView setImage:[UIImage imageNamed:@"Title_Crop.png"]];
            [self.cropOverlay setOverlayType:kCropOverlayRuleOfThirds];
            sliderVal = ratioToSliderValue([self.cropOverlay getCropAspectRatio], self.maxAspectRatio);
            break;
            
        case kToolIDRotate:
            controlContents = [[NSBundle mainBundle] loadNibNamed:@"Controls_Rotate" owner:self options:nil];
            optionsContents = [[NSBundle mainBundle] loadNibNamed:@"Options_Rotate" owner:self options:nil];
            [self.titleView setImage:[UIImage imageNamed:@"Title_Rotate.png"]];

            sliderVal = [self calcRotationSliderValue];
            self.prevRotateSliderVal = sliderVal;

            [self.cropOverlay setOverlayType:kCropOverlayGrid];
            break;
            
        case kToolIDPerspective:
            controlContents = [[NSBundle mainBundle] loadNibNamed:@"Controls_Perspective" owner:self options:nil];
            optionsContents = [[NSBundle mainBundle] loadNibNamed:@"Options_Perspective" owner:self options:nil];
            break;
            
        default:
            break;
    }
    
    if (controlContents && optionsContents) {
        [self.displayedControlView removeFromSuperview];
        self.displayedControlView = [controlContents objectAtIndex:0];
        [self.controlBar addSubview:self.displayedControlView];
        setupStraightSlider(self.currentSlider);
        
        [self.displayedOptionView removeFromSuperview];
        self.displayedOptionView = [optionsContents objectAtIndex:0];
        [self.optionBar addSubview:self.displayedOptionView];
    }
    
    [self.currentSlider setValue:sliderVal];
    
    if (contentID == kToolIDCrop && UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
        NSArray *extraContents = [[NSBundle mainBundle] loadNibNamed:@"Options_AspectRatios" owner:self options:nil];
        UIView *extraView = [extraContents objectAtIndex:0];
        CGSize extraSize = extraView.frame.size;
        [self.optionsScrollView setContentSize:extraSize];
        [self.optionsScrollView addSubview:extraView];
        [self.optionsScrollView setContentOffset:CGPointMake((extraSize.width - self.optionsScrollView.frame.size.width) / 2, 0.0) animated:NO];
    } else {
        self.optionsScrollView = nil;
    }

    [self.cropTool setSelected:contentID == kToolIDCrop];
    [self.rotateTool setSelected:contentID == kToolIDRotate];
    
    self.currentToolID = contentID;
}

#pragma mark - always available user actions

- (IBAction)doApply:(id)sender {
    if ([self.cropOverlay isAutoDisplayEnabled])
        [self.cropOverlay toggleAutoDisplay];
    [self.dataController setCropImageOrientation:[self.cropOverlay getImageOrientation]];
    [self.dataController setCropSourceImageSize:[self.cropOverlay getCropSourceImageSize]];
    [self.dataController setCropTransform:[self.cropOverlay getCropTransform]];
    [self.dataController setCropAspectRatio:[self.cropOverlay getCropAspectRatio]];
    [self.dataController applyTools];

    [self.delegate doCloseToolView:self];
}

- (IBAction)doCancel:(id)sender {
    if ([self.cropOverlay isAutoDisplayEnabled])
        [self.cropOverlay toggleAutoDisplay];
    [self.delegate doCloseToolView:self];
}

- (IBAction)doResetEverything:(id)sender {
    self.prevRotateSliderVal = 0.0;
    [self.cropOverlay resetAllTransforms];
    if (self.currentToolID == kToolIDCrop)
        [self.currentSlider setValue:ratioToSliderValue([self.cropOverlay getCropAspectRatio], self.maxAspectRatio)];
    else
        [self.currentSlider reset];
}

- (IBAction)toggleAutoDisplay:(id)sender {
    [self.cropOverlay toggleAutoDisplay];
    UIButton *button = (UIButton *)sender;
    [button setSelected:!button.isSelected];
}

- (IBAction)doShowCrop:(id)sender {
    [self setToolContent:kToolIDCrop];
}

- (IBAction)doShowRotate:(id)sender {
    [self setToolContent:kToolIDRotate];
}

- (IBAction)doShowPerspective:(id)sender {
    [self setToolContent:kToolIDPerspective];
}

#pragma mark - rotating & flipping

- (IBAction)doFlipHorizontal:(id)sender {
    [self.cropOverlay doFlipImageHorizontal];
}

- (IBAction)doFlipVertical:(id)sender {
    [self.cropOverlay doFlipImageVertical];
}

- (IBAction)doRotate90Right:(id)sender {
    [self.cropOverlay doRotateImage90Right];
}

- (IBAction)doRotate90Left:(id)sender {
    [self.cropOverlay doRotateImage90Left];
}

- (IBAction)doRotateSliderStarted:(PTGSlider *)sender {
    self.prevRotateSliderVal = sender.value;
}

- (IBAction)doRotateSliderValueChanged:(PTGSlider *)sender {
    [self.cropOverlay adjustCropRotation:degreesToRadians(sender.value - self.prevRotateSliderVal)];
    self.prevRotateSliderVal = sender.value;
}

- (IBAction)doRotateSliderStopped:(PTGSlider *)sender {
}

- (IBAction)doRotateSliderTouch:(PTGSlider *)sender {
}

#pragma mark - cropping

// assumes slider is -1 to 0 to 1 AND ratio is maxRatio to 1.0 to 1 / maxRatio

float sliderValToRatio(float value, float maxRatio) {
    float ratio = 1.0;
    
    if (value < 0.0) {
        ratio = (1 - maxRatio) * value + 1;
    } else {
        ratio = (1 - maxRatio) * value / maxRatio + 1;
    }
    
    return ratio;
}

float ratioToSliderValue(CGFloat ratio, float maxRatio) {
    CGFloat value = 0.0;
    
    if (ratio > 1.0) {
        value = (1 - ratio) / (maxRatio - 1);
   } else {
        value = - maxRatio * ratio / (maxRatio - 1) + maxRatio / (maxRatio - 1);
    }
    
    return value;
}

- (void)setAspectRatioRatioWithWidth:(CGFloat)ratio_w andHeight:(CGFloat)ratio_h {
    [self setAspectRatio:ratio_w / ratio_h];
}

-(void)setAspectRatio:(CGFloat)ratio {
    [self.cropOverlay setAspectRatio:ratio];
    [self.currentSlider setValue:ratioToSliderValue(ratio, self.maxAspectRatio)];
}

- (IBAction)doAspectSixteenNine:(id)sender {
    [self setAspectRatioRatioWithWidth:16.0 andHeight:9.0];
}

- (IBAction)doAspectSevenFive:(id)sender {
    [self setAspectRatioRatioWithWidth:7.0 andHeight:5.0];
}

- (IBAction)doAspectThreeTwo:(id)sender {
    [self setAspectRatioRatioWithWidth:3.0 andHeight:2.0];
}

- (IBAction)doAspectFourThree:(id)sender {
    [self setAspectRatioRatioWithWidth:4.0 andHeight:3.0];
}

- (IBAction)doAspectFiveFour:(id)sender {
    [self setAspectRatioRatioWithWidth:5.0 andHeight:4.0];
}

- (IBAction)doAspectOneOne:(id)sender {
    [self setAspectRatioRatioWithWidth:1.0 andHeight:1.0];
}

- (IBAction)doAspectFourFive:(id)sender {
    [self setAspectRatioRatioWithWidth:4.0 andHeight:5.0];
}

- (IBAction)doAspectThreeFour:(id)sender {
    [self setAspectRatioRatioWithWidth:3.0 andHeight:4.0];
}

- (IBAction)doAspectTwoThree:(id)sender {
    [self setAspectRatioRatioWithWidth:2.0 andHeight:3.0];
}

- (IBAction)doAspectFiveSeven:(id)sender {
    [self setAspectRatioRatioWithWidth:5.0 andHeight:7.0];
}

- (IBAction)doAspectNineSixteen:(id)sender {
    [self setAspectRatioRatioWithWidth:9.0 andHeight:16.0];
}

- (IBAction)doCropSliderStarted:(PTGSlider *)sender {
}

- (IBAction)doCropSliderValueChanged:(PTGSlider *)sender {
    [self.cropOverlay setAspectRatio:sliderValToRatio(sender.value, self.maxAspectRatio)];
}

- (IBAction)doCropSliderStopped:(PTGSlider *)sender {
}

- (IBAction)doCropSliderTouch:(PTGSlider *)sender {
}

#pragma mark - CropOverlayViewDelegate

- (void)rotationAngleChanged:(CropOverlayView *)view {
    float sliderVal = [self calcRotationSliderValue];
    self.prevRotateSliderVal = sliderVal;
    [self.currentSlider setValue:sliderVal];
}

@end
