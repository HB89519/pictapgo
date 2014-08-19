//
//  PreviewViewController.m
//  RadLab
//
//  Created by Geoff Scott on 11/6/12.
//  Copyright (c) 2012 Totally Rad. All rights reserved.
//

#import "PreviewViewController.h"
#import <QuartzCore/CALayer.h>
#import <QuartzCore/CATransaction.h>

@interface PreviewViewController ()
{
	CGFloat beginGestureScale;
	CGFloat effectiveScale;
    CGFloat reverseScale;
    BOOL isShowingAfter;
}
- (void)setAfterImageStrength:(float)strength;
@end

@implementation PreviewViewController

@synthesize dataController = _dataController;
@synthesize afterImageView = _afterImageView;
@synthesize beforeImageView = _beforeImageView;
@synthesize beforeAfterButton = _beforeAfterButton;
@synthesize delegate = _delegate;
@synthesize scrollView = _scrollView;
@synthesize containerView = _containerView;
@synthesize strengthSlider = _strengthSlider;
@synthesize strengthText = _strengthText;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)setAfterImageStrength:(float)strength {
    float gammaCorrectedStrength = pow(strength, 1.0);
    [self.afterImageView setAlpha:gammaCorrectedStrength];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

	effectiveScale = 1.0;
    beginGestureScale = 1.0;
    reverseScale = 1.0;
    isShowingAfter = YES;
    
    // remove all the constraints added by the storyboard, since it really messes with smooth zooming
    [self.scrollView removeConstraints:[self.scrollView constraints]];
    
#if geofftest
    [self.afterImageView setHidden:YES];
    [self.afterImageView setImage:self.dataController.currentPreviewAtFullStrength];
    CGSize newImageSize = [self.afterImageView.image size];
    CGRect newFrame = CGRectMake(self.afterImageView.frame.origin.x, self.afterImageView.frame.origin.y, newImageSize.width, newImageSize.height);
    [self.containerView setFrame:newFrame];
    [self.afterImageView setFrame:newFrame];
    
    [self.beforeImageView setHidden:YES];
    [self.beforeImageView setImage:self.dataController.previousPreview];
    [self.beforeImageView setFrame:newFrame];

    [self.scrollView setContentSize:newFrame.size];
#else
    [self.dataController startSpeculativeResizing];
    
    [self.afterImageView setHidden:YES];
    [self.beforeImageView setHidden:YES];
#endif

    UITapGestureRecognizer *doubleTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
    doubleTapRecognizer.numberOfTapsRequired = 2;
    doubleTapRecognizer.numberOfTouchesRequired = 1;
    [self.scrollView addGestureRecognizer:doubleTapRecognizer];
}

- (void)viewDidUnload
{
    // unload things above this call
    [super viewDidUnload];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

#if !geofftest
    [self.beforeImageView setImage:self.dataController.previousLarge];
    CGSize newImageSize = [self.beforeImageView.image size];
    CGRect newFrame = CGRectMake(self.beforeImageView.frame.origin.x, self.beforeImageView.frame.origin.y, newImageSize.width, newImageSize.height);
    [self.beforeImageView setFrame:newFrame];
    [self.containerView setFrame:newFrame];
    
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [spinner setColor:[UIColor yellowColor]];
//    CGRect spinnerFrame = CGRectMake(newFrame.size.width / 2 - 100 + newFrame.origin.x, newFrame.size.height / 2 - 100 + newFrame.origin.y, 200, 200);
//    [spinner setFrame:spinnerFrame];
//    NSLog(@"spinnerRect = %f x %f at (%f, %f)", spinnerFrame.size.width, spinnerFrame.size.height, spinnerFrame.origin.x, spinnerFrame.origin.y);
//    NSLog(@"newFrame = %f x %f at (%f, %f)", newFrame.size.width, newFrame.size.height, newFrame.origin.x, newFrame.origin.y);
//    [self.containerView addSubview:spinner];
    [spinner sizeToFit];
    spinner.center = CGPointMake(160, 240);
    spinner.hidesWhenStopped = YES;
    [self.view addSubview:spinner];
    [spinner startAnimating];
    
    [self.afterImageView setImage:self.dataController.currentLarge];    
    [self.afterImageView setFrame:newFrame];
    
//    [spinner stopAnimating];
//    [spinner removeFromSuperview];
//    spinner = nil;
    
    [self.scrollView setContentSize:newFrame.size];
#endif

    CGRect scrollViewFrame = self.scrollView.frame;
    CGFloat scaleWidth = scrollViewFrame.size.width / self.scrollView.contentSize.width;
    CGFloat scaleHeight = scrollViewFrame.size.height / self.scrollView.contentSize.height;
    CGFloat minScale = MIN(scaleWidth, scaleHeight);
    self.scrollView.minimumZoomScale = minScale;
    self.scrollView.maximumZoomScale = 1.0f;
    self.scrollView.zoomScale = minScale;
    
    [self.afterImageView setHidden:!isShowingAfter];
    [self.beforeImageView setHidden:NO];

    [self.strengthText setText:[NSString stringWithFormat:@"%d %%", [[self.dataController currentStrength] integerValue]]];
    [self.strengthSlider setMinimumValue:0.0];
    [self.strengthSlider setMaximumValue:100.0];
    [self.strengthSlider setValue:[[self.dataController currentStrength] floatValue] animated:NO];
}

- (void)didReceiveMemoryWarning
{
    NSLog(@"Preview view received memory warning");
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)doApply:(id)sender {
    [self.dataController setCurrentStrength:[NSNumber numberWithFloat:[self.strengthSlider value]]];
// geofftest - if strength has changed, must rebuild the whole thumbnail list
    [[self delegate] previewViewControllerDidApply:self];
}

- (IBAction)doCancel:(id)sender {
    [[self delegate] previewViewControllerDidCancel:self];
}

- (IBAction)doBeforeAfter:(id)sender {
    if (isShowingAfter) {
        [self.beforeAfterButton setTitle:@"After"];
    } else {
        [self.beforeAfterButton setTitle:@"Before"];
    }
    isShowingAfter = !isShowingAfter;
    [self.afterImageView setHidden:!isShowingAfter];
}

- (IBAction)doSliderValueChanged:(UISlider *)sender {
    [self setAfterImageStrength:sender.value / 100.0];
    NSUInteger displayStrength = sender.value;
    [self.strengthText setText:[NSString stringWithFormat:@"%d %%", displayStrength]];
}

- (IBAction)handleDoubleTap:(UIPinchGestureRecognizer *)recognizer {
    [self.scrollView setZoomScale:self.scrollView.minimumZoomScale animated:YES];
}

- (IBAction)handleLongPress:(UILongPressGestureRecognizer *)recognizer {
    BOOL bInsideImageView = NO;
    
    NSUInteger numTouches = [recognizer numberOfTouches];
	for (NSUInteger i = 0; i < numTouches; ++i ) {
		CGPoint location = [recognizer locationOfTouch:i inView:self.scrollView];
        location.x -= self.scrollView.contentOffset.x;
        location.y -= self.scrollView.contentOffset.y;
        if (CGRectContainsPoint(self.scrollView.frame, location)) {
            bInsideImageView = YES;
        }
    }
    
    if (bInsideImageView) {
        if ([recognizer state] == UIGestureRecognizerStateBegan) {
            if (numTouches > 1) {
                [self.beforeImageView setImage:self.dataController.masterLarge];
            }
            [self.afterImageView setHidden:YES];
        } else if ([recognizer state] == UIGestureRecognizerStateEnded) {
            [self.afterImageView setHidden:NO];
            [self.beforeImageView setImage:self.dataController.previousLarge];
        }
    }
}

#pragma mark - ImageDataControllerDelegate

- (void)setDataController:(ImageDataController *)controller {
    _dataController = controller;
}

#pragma mark - UIScrollViewDelegate

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return self.containerView;
}

- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(float)scale {
}

@end
