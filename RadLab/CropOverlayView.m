//
//  CropOverlayView.m
//  RadLab
//
//  Created by Geoff Scott on 3/7/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import "CropOverlayView.h"
#import <QuartzCore/QuartzCore.h>
#import "UICommon.h"

static int ddLogLevel = LOG_LEVEL_INFO;

@interface CropOverlayView ()

// transform for the image and crop grid to fit on screen
@property (nonatomic, assign) CGAffineTransform canvasTransform;

// transform applied to image to reflect orientation
@property (nonatomic, assign) CGAffineTransform imageOrientTransform;

// transform applied to crop to reflect orientation
@property (nonatomic, assign) CGAffineTransform cropOrientTransform;

// saved transform initially applied to the crop grid
@property (nonatomic, assign) CGAffineTransform initCropTransform;

// saved transform initially applied to the image
@property (nonatomic, assign) CGAffineTransform initImageTransform;

// saved image orientation applied to the image
@property (nonatomic, assign) UIImageOrientation initImageOrientation;

// transform to keep the crop rect in the display area
@property (nonatomic, assign) CGAffineTransform displayTransform;

@property (nonatomic, assign) CGRect initFrame;
@property (nonatomic, assign) CGSize initScaledImageSize;
@property (nonatomic, assign) BOOL autoDisplayEnabled;
@property (nonatomic, assign) CGFloat prevUserScale;
@property (weak, nonatomic) UIImageView *imageView;
@property (weak, nonatomic) GridLineView *gridView;
@property (nonatomic, weak) UIRotationGestureRecognizer *rotateGestureRecognizer;

@end

@implementation CropOverlayView

// public
@synthesize delegate = _delegate;
@synthesize maskView = _maskView;

// private
@synthesize canvasTransform = _canvasTransform;
@synthesize imageOrientTransform = _imageOrientTransform;
@synthesize cropOrientTransform = _cropOrientTransform;
@synthesize initCropTransform = _initCropTransform;
@synthesize initImageTransform = _initImageTransform;
@synthesize initImageOrientation = _initImageOrientation;
@synthesize displayTransform = _displayTransform;
@synthesize initFrame = _initFrame;
@synthesize initScaledImageSize = _initScaledImageSize;
@synthesize autoDisplayEnabled = _autoDisplayEnabled;
@synthesize prevUserScale = _prevUserScale;
@synthesize imageView = _imageView;
@synthesize gridView = _gridView;
@synthesize rotateGestureRecognizer = _rotateGestureRecognizer;

#pragma mark - set up

- (void)initCommon {
    UITapGestureRecognizer *doubleTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
    doubleTapRecognizer.numberOfTapsRequired = 2;
    doubleTapRecognizer.numberOfTouchesRequired = 1;
    [self addGestureRecognizer:doubleTapRecognizer];
    
    UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self addGestureRecognizer:panGestureRecognizer];
    
    UIPinchGestureRecognizer *pinchGestureRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)];
    [self addGestureRecognizer:pinchGestureRecognizer];
    
    UIRotationGestureRecognizer *rotateGestureRecognizer = [[UIRotationGestureRecognizer alloc] initWithTarget:self action:@selector(handleRotation:)];
    [self addGestureRecognizer:rotateGestureRecognizer];
    self.rotateGestureRecognizer = rotateGestureRecognizer;
    [self.rotateGestureRecognizer setRotation:0.0];
    
    self.autoDisplayEnabled = YES;
    self.prevUserScale = 1.0;
    self.displayTransform = CGAffineTransformIdentity;
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
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

- (void)setUpWithImage:(UIImage *)image
   andImageOrientation:(UIImageOrientation)orientation
      andCropTransform:(CGAffineTransform)cropTransform
    andCropAspectRatio:(CGFloat)aspectRatio {
    
    // geofftest - may need to do this if layout view called again
    [self removeConstraints:self.constraints];
    self.initFrame = self.frame;
    self.initImageOrientation = orientation;
    
    CGSize imageSize = image.size;
    CGRect imageFrame = CGRectMake(0.0, 0.0, imageSize.width, imageSize.height);
    UIImageView *tempImageView = [[UIImageView alloc] initWithFrame:imageFrame];
    [tempImageView setContentMode:UIViewContentModeScaleAspectFit];
    [self addSubview:tempImageView];
    self.imageView = tempImageView;
    [self.imageView setImage:image];

    CGFloat initScale = MIN(self.frame.size.width / imageSize.width, self.frame.size.height / imageSize.height);
    CGAffineTransform scaleT = CGAffineTransformMakeScale(initScale, initScale);

    CGPoint centerOffset = CGPointMake(self.center.x - self.frame.origin.x - self.imageView.center.x, self.center.y - self.frame.origin.y - self.imageView.center.y);
    CGAffineTransform imageMoveT = CGAffineTransformMakeTranslation(centerOffset.x, centerOffset.y);
    [self setCanvasTransform:CGAffineTransformConcat(scaleT, imageMoveT)];
    [self.imageView setTransform:CGAffineTransformConcat(self.imageView.transform, self.canvasTransform)];

    self.initScaledImageSize = image.size;
    
    [self setImageOrientTransform:applyOrientationToTransform(self.initImageOrientation, CGAffineTransformIdentity, YES)];
    [self.imageView setTransform:CGAffineTransformConcat(self.imageOrientTransform, self.imageView.transform)];
    self.initImageTransform = self.imageView.transform;

    GridLineView *tempGrid = [[GridLineView alloc] initWithFrame:CGRectMake(0.0, 0.0, imageSize.width, imageSize.height)];
    [tempGrid setBackgroundColor:[UIColor clearColor]];
    [tempGrid setContentMode:UIViewContentModeScaleAspectFit];
    [self addSubview:tempGrid];
    self.gridView = tempGrid;
    [self.gridView setConstrainingRect:CGRectMake(0.0, 0.0, imageSize.width, imageSize.height)];
    
    self.initCropTransform = adjustTranslationsForOrientation(self.initImageOrientation, cropTransform, NO);
    [self setCropOrientTransform:applyOrientationToTransform(self.initImageOrientation, CGAffineTransformIdentity, NO)];
    self.initCropTransform = CGAffineTransformConcat(CGAffineTransformConcat(CGAffineTransformConcat(self.gridView.transform, self.initCropTransform), self.cropOrientTransform), self.canvasTransform);
    [self.gridView setTransform:self.initCropTransform];
    [self.gridView setInitAspectRatio:aspectRatio];
    self.prevUserScale = xscaleFromTransform(self.gridView.transform);

    [self snapCropInsideImage];
    [self displayCropScaled];
    [self displayCropUnrotated:-fmodf(rotationFromTransform(self.gridView.transform), M_PI / 2)];
    [self displayCropCentered];

    [self.rotateGestureRecognizer setRotation:0.0];
}

- (void)setOverlayType:(CropOverlayType) newType {
    [self.gridView setOverlayType:newType];
}

#pragma mark - results

- (CGAffineTransform)getCropTransform {
    CGAffineTransform returnT = CGAffineTransformConcat(self.gridView.transform, CGAffineTransformInvert(self.canvasTransform));
    returnT = CGAffineTransformConcat(returnT, CGAffineTransformInvert(self.cropOrientTransform));
    
    // special case BS because of how flips are applied to the image and not the gridview
    UIImageOrientation orientation = [self getImageOrientation];
    CGFloat gridAngle = radiansToDegrees(rotationFromTransform(self.gridView.transform));
    BOOL flag = YES;
    if (orientation == UIImageOrientationLeftMirrored && gridAngle < 0) {
        flag = NO;
    } else if (orientation == UIImageOrientationRightMirrored && gridAngle > 0) {
        flag = NO;
    } else if (orientation == UIImageOrientationLeft && gridAngle > 0) {
        flag = NO;
    } else if (orientation == UIImageOrientationRight && gridAngle < 0) {
        flag = NO;
    } else if (orientation == UIImageOrientationDownMirrored
               && (gridAngle < 90 && gridAngle > -90)) {
        flag = NO;
    } else if (orientation == UIImageOrientationUpMirrored
               && (gridAngle < 90 && gridAngle > -90)) {
        flag = NO;
    } else if (orientation == UIImageOrientationUp
               && (gridAngle < 45 && gridAngle > -45)) {
        flag = NO;
    } else if (orientation == UIImageOrientationDown
               && (gridAngle > 45 || gridAngle < -45)) {
        flag = NO;
    }
    
    returnT = adjustTranslationsForOrientation(orientation, returnT, flag);    
    return returnT;
}

- (UIImageOrientation)getImageOrientation {
    return imageOrientationFromTransform(self.imageView.transform);
}

- (CGSize)getCropSourceImageSize {
    return self.initScaledImageSize;
}

- (CGFloat)getCropAspectRatio {
    return self.gridView.curAspectRatio;
}

- (CGFloat)getRotationAngle {
    return rotationFromTransform(self.gridView.transform);
}

#pragma mark - display

- (void)adjustToNewFrame:(CGRect)parentFrame {
    [UIView animateWithDuration:0.25 animations:^{
        CGPoint newCenter = CGPointMake(parentFrame.size.width / 2, parentFrame.size.height / 2);
        self.center = newCenter;

        [self.maskView setFrame:parentFrame];
    
        CGRect initFrame = self.initFrame;
        initFrame.size = parentFrame.size;
        self.initFrame = initFrame;
    
        [self displayCropScaled];
        [self displayCropCentered];
        [self updateMask];    
    }];
}

- (BOOL)isAutoDisplayEnabled {
    return self.autoDisplayEnabled;
}

- (void)toggleAutoDisplay {
    self.autoDisplayEnabled = !self.autoDisplayEnabled;
    if (!self.autoDisplayEnabled) {
        [UIView animateWithDuration:0.25 animations:^{
            [self setTransform:CGAffineTransformIdentity];
        }];
    } else {
        [UIView animateWithDuration:0.25 animations:^{
            [self setTransform:self.displayTransform];
        }];
    }
    [self snapCropInsideImage];
    [self displayCropCentered];
    [self updateMask];
}

- (void)displayCropScaled {
    // scale self so the crop rect fills the display area
    CGRect destRect = self.initFrame;
    CGRect cropBounds = self.gridView.bounds;
    cropBounds = CGRectApplyAffineTransform(cropBounds, CGAffineTransformRotate(self.gridView.transform, -rotationFromTransform(self.gridView.transform)));
    cropBounds.size.width *= xscaleFromTransform(self.displayTransform);
    cropBounds.size.height *= yscaleFromTransform(self.displayTransform);
    CGFloat newScale = MIN(destRect.size.width / cropBounds.size.width, destRect.size.height / cropBounds.size.height);
    
    self.displayTransform = CGAffineTransformScale(self.displayTransform, newScale, newScale);
    [self updateDisplay];
}

- (void)displayCropCentered {
    // position self so that crop is centered in the display area
    if (self.autoDisplayEnabled) {
        CGPoint targetCenter = self.center;    
        CGPoint gridCenter = [self calcGridCenterPoint];
        CGPoint adjust;
        adjust.x = targetCenter.x - gridCenter.x;
        adjust.y = targetCenter.y - gridCenter.y;
        adjust.x = adjust.x / xscaleFromTransform(self.displayTransform);
        adjust.y = adjust.y / yscaleFromTransform(self.displayTransform);

        self.displayTransform = CGAffineTransformTranslate(self.displayTransform, adjust.x, adjust.y);
        [self updateDisplay];
    } else {
        CGPoint gridCenterTranslate = [self convertPoint:self.gridView.center fromView:self.gridView];
        
        CGPoint targetCenter = self.center;
        targetCenter.x -= txFromTransform(self.displayTransform) / xscaleFromTransform(self.displayTransform);
        targetCenter.y -= tyFromTransform(self.displayTransform) / yscaleFromTransform(self.displayTransform);
        
        CGFloat adjustX = targetCenter.x - gridCenterTranslate.x;
        CGFloat adjustY = targetCenter.y - gridCenterTranslate.y;
        
        self.displayTransform = CGAffineTransformTranslate(self.displayTransform, adjustX, adjustY);
        [self updateDisplay];
    }
}

- (void)displayCropUnrotated:(CGFloat)deltaAngleInRadians {
    self.displayTransform = CGAffineTransformRotate(self.displayTransform, deltaAngleInRadians);
    [self updateDisplay];
}

- (void)updateDisplay {
    if (self.autoDisplayEnabled) {
        [self setTransform:self.displayTransform];
    }
}

- (void) updateMask {
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.frame = self.maskView.bounds;
    
    CGMutablePathRef cutoutPath = CGPathCreateMutable();
    
    // frame it
    CGPathMoveToPoint(cutoutPath, NULL, self.maskView.bounds.origin.x, self.maskView.bounds.origin.y);
    CGPathAddLineToPoint(cutoutPath, NULL, self.maskView.bounds.origin.x, self.maskView.bounds.origin.y + self.maskView.bounds.size.height);
    CGPathAddLineToPoint(cutoutPath, NULL, self.maskView.bounds.origin.x + self.maskView.bounds.size.width, self.maskView.bounds.origin.y + self.maskView.bounds.size.height);
    CGPathAddLineToPoint(cutoutPath, NULL, self.maskView.bounds.origin.x + self.maskView.bounds.size.width, self.maskView.bounds.origin.y);
    CGPathAddLineToPoint(cutoutPath, NULL, self.maskView.bounds.origin.x, self.maskView.bounds.origin.y);
    
    // cut out the gird area
    CGPoint tempPt = transformedTopLeft(self.gridView);
    tempPt = [self convertPoint:tempPt toView:self.maskView];
    CGPathMoveToPoint(cutoutPath, NULL, tempPt.x, tempPt.y);
    
    tempPt = transformedTopRight(self.gridView);
    tempPt = [self convertPoint:tempPt toView:self.maskView];
    CGPathAddLineToPoint(cutoutPath, NULL, tempPt.x, tempPt.y);
    
    tempPt = transformedBottomRight(self.gridView);
    tempPt = [self convertPoint:tempPt toView:self.maskView];
    CGPathAddLineToPoint(cutoutPath, NULL, tempPt.x, tempPt.y);
    
    tempPt = transformedBottomLeft(self.gridView);
    tempPt = [self convertPoint:tempPt toView:self.maskView];
    CGPathAddLineToPoint(cutoutPath, NULL, tempPt.x, tempPt.y);
    
    tempPt = transformedTopLeft(self.gridView);
    tempPt = [self convertPoint:tempPt toView:self.maskView];
    CGPathAddLineToPoint(cutoutPath, NULL, tempPt.x, tempPt.y);
    
    // use it
    maskLayer.path = cutoutPath;
    self.maskView.layer.mask = maskLayer;
    self.maskView.layer.masksToBounds = YES;
    
    CGPathRelease(cutoutPath);
}

#pragma mark - change the crop rect

- (void)resetAllTransforms {
    [UIView animateWithDuration:0.25 animations:^{
        self.displayTransform = CGAffineTransformIdentity;
        [self setTransform:self.displayTransform];
        
        [self.imageView setTransform:self.canvasTransform];
        [self setInitImageOrientation:UIImageOrientationUp];
        self.imageOrientTransform = CGAffineTransformIdentity;
        
        [self.gridView setTransform:self.canvasTransform];
        self.initCropTransform = CGAffineTransformIdentity;
        self.cropOrientTransform = CGAffineTransformIdentity;
        [self.gridView setInitAspectRatio:self.imageView.bounds.size.width / self.imageView.bounds.size.height];
        self.prevUserScale = xscaleFromTransform(self.gridView.transform);
        
        [self.rotateGestureRecognizer setRotation:0.0];
        
        [self displayCropScaled];
        [self displayCropCentered];
        [self updateMask];
    }];
}

- (void)setAspectRatioWithWidth:(CGFloat)ratio_w andHeight:(CGFloat)ratio_h {
    return [self setAspectRatio:ratio_w / ratio_h];
}

- (void)setAspectRatio:(CGFloat)newRatio {
    [self.gridView setCurAspectRatio:newRatio];
    
    [self scaleCropToInsideImage];
    [self snapCropInsideImage];
    
    [self displayCropScaled];
    [self displayCropCentered];
    [self updateMask];
}

- (void)doFlipImageHorizontal {
    [UIView animateWithDuration:0.25 animations:^{
        [self.imageView setTransform:CGAffineTransformScale(self.imageView.transform, -1, 1)];
        self.imageOrientTransform = CGAffineTransformScale(self.imageOrientTransform, -1, 1);
        
        [self snapCropInsideImage];
        [self displayCropCentered];
        [self updateMask];
    }];
}

- (void)doFlipImageVertical {
    [UIView animateWithDuration:0.25 animations:^{
        [self.imageView setTransform:CGAffineTransformScale(self.imageView.transform, 1, -1)];
        self.imageOrientTransform = CGAffineTransformScale(self.imageOrientTransform, 1, -1);
        
        [self snapCropInsideImage];
        [self displayCropCentered];
        [self updateMask];
    }];
}

- (void)doRotateImage90Right {
    [UIView animateWithDuration:0.25 animations:^{
        [self.imageView setTransform:CGAffineTransformRotate(self.imageView.transform, degreesToRadians(90.0))];
        self.imageOrientTransform = CGAffineTransformRotate(self.imageOrientTransform, degreesToRadians(90.0));
        
        [self.gridView setTransform:CGAffineTransformRotate(self.gridView.transform, degreesToRadians(90.0))];
        self.cropOrientTransform = CGAffineTransformRotate(self.cropOrientTransform, degreesToRadians(90.0));
        
        [self snapCropInsideImage];
        [self displayCropCentered];
        [self updateMask];
    }];
}

- (void)doRotateImage90Left {
    [UIView animateWithDuration:0.25 animations:^{
        [self.imageView setTransform:CGAffineTransformRotate(self.imageView.transform, degreesToRadians(-90.0))];
        self.imageOrientTransform = CGAffineTransformRotate(self.imageOrientTransform, degreesToRadians(-90.0));
        
        [self.gridView setTransform:CGAffineTransformRotate(self.gridView.transform, degreesToRadians(-90.0))];
        self.cropOrientTransform = CGAffineTransformRotate(self.cropOrientTransform, degreesToRadians(-90.0));
        
        [self snapCropInsideImage];
        [self displayCropCentered];
        [self updateMask];
    }];
}

- (void)snapCropInsideImage {
    CGRect newCropRect = self.gridView.frame;
    CGRect imageBox = self.imageView.frame;
    CGPoint adjust = CGPointMake(0.0, 0.0);
    if (newCropRect.origin.x < imageBox.origin.x)
        adjust.x =  imageBox.origin.x - newCropRect.origin.x;
    if (newCropRect.origin.x + newCropRect.size.width > imageBox.origin.x + imageBox.size.width)
        adjust.x = imageBox.origin.x + imageBox.size.width - newCropRect.origin.x - newCropRect.size.width;
    
    if (newCropRect.origin.y < imageBox.origin.y)
        adjust.y =  imageBox.origin.y - newCropRect.origin.y;
    if (newCropRect.origin.y + newCropRect.size.height > imageBox.origin.y + imageBox.size.height)
        adjust.y = imageBox.origin.y + imageBox.size.height - newCropRect.origin.y - newCropRect.size.height;

    adjust = [self correctPoint:adjust fromTransform:self.gridView.transform];
    adjust.x /= xscaleFromTransform(self.gridView.transform);
    adjust.y /= yscaleFromTransform(self.gridView.transform);
    
    [self.gridView setTransform:CGAffineTransformTranslate(self.gridView.transform, adjust.x, adjust.y)];
}

- (CGPoint)correctPoint:(CGPoint)point fromTransform:(CGAffineTransform)transform {
    CGPoint retPoint = CGPointMake(point.x, point.y);
    
    // frame axes are correct to screen, but transform axes are not, so change adjusts accordingly
    CGFloat angle = radiansToDegrees(rotationFromTransform(transform));
    if (angle >= 0.0 && angle < 90.0) {
        retPoint.x = retPoint.x;
        retPoint.y = retPoint.y;
    } else if (angle >= 90.0 && angle < 180.0) {
        CGFloat tempAdj = retPoint.x;
        retPoint.x = retPoint.y;
        retPoint.y = -tempAdj;
    } else if (angle < 0.0 && angle >= -90.0) {
        CGFloat tempAdj = retPoint.x;
        retPoint.x = -retPoint.y;
        retPoint.y = tempAdj;
    } else if (angle == 180.0 || (angle < -90.0 && angle >= -180.0)) {
        retPoint.x = -retPoint.x;
        retPoint.y = -retPoint.y;
    } else {
        DDLogError(@"correctPoint found an angle that should not exist!!");
    }
    
    // flip horizontal gives false angle as -180, so must undo that change here
    if (determinantFromTransform(transform) < 0.0 && rotationFromTransform(transform) != 0.0) {
        retPoint.x = -retPoint.x;
        retPoint.y = -retPoint.y;
    }
    
    return retPoint;
}

- (void)adjustCropPosition:(CGPoint)deltaOffset {
    // delta comes in relative to the screen, must make it relative to the (potentially) rotated canvas (self)
    CGPoint newDelta = deltaOffset;
    CGFloat canvasAngle = rotationFromTransform(self.transform);
//    CGPoint tempDelta = [self correctPoint:deltaOffset fromTransform:self.transform];   // note care about view's actual transform (not the display transform)
    CGPoint tempDelta = newDelta;
    newDelta.x = tempDelta.x * cosf(canvasAngle) - tempDelta.y * sinf(canvasAngle);
    newDelta.y = tempDelta.x * sinf(canvasAngle) + tempDelta.y * cosf(canvasAngle);
    
    // want deltaOffset to be used as is, so must undo/redo rotation to get the right results
    CGFloat angle = rotationFromTransform(self.gridView.transform);
    [self.gridView setTransform:CGAffineTransformRotate(self.gridView.transform, -angle)];
    [self.gridView setTransform:CGAffineTransformTranslate(self.gridView.transform, newDelta.x, newDelta.y)];
    [self.gridView setTransform:CGAffineTransformRotate(self.gridView.transform, angle)];
    [self snapCropInsideImage];

    [self displayCropScaled];
    [self displayCropCentered];
    [self updateMask];
}

- (CGFloat)calcScaleToFit {
    CGFloat newScale = 1.0;
    CGRect newCropRect = self.gridView.frame;
    CGRect imageBox = self.imageView.frame;
    if (newCropRect.size.width > imageBox.size.width && newCropRect.size.height > imageBox.size.height) {
        newScale = MIN(imageBox.size.width / newCropRect.size.width, imageBox.size.height / newCropRect.size.height);
    } else if (newCropRect.size.width > imageBox.size.width) {
        newScale = imageBox.size.width / newCropRect.size.width;
    } else if (newCropRect.size.height > imageBox.size.height) {
        newScale = imageBox.size.height / newCropRect.size.height;
    }
    return newScale;
}

- (void)scaleCropToInsideImage {
    CGFloat newScale = [self calcScaleToFit];
    
    if (newScale == 1.0) {
        CGFloat curScale = xscaleFromTransform(self.gridView.transform);
        newScale = self.prevUserScale / curScale;
        [self.gridView setTransform:CGAffineTransformScale(self.gridView.transform, newScale, newScale)];
        newScale = [self calcScaleToFit];
    }
    
    if (newScale != 1.0) {
        [self.gridView setTransform:CGAffineTransformScale(self.gridView.transform, newScale, newScale)];
    }
}

- (void)adjustCropScale:(CGFloat)newScale {
    [self.gridView setTransform:CGAffineTransformScale(self.gridView.transform, newScale, newScale)];
    self.prevUserScale = xscaleFromTransform(self.gridView.transform);
    [self scaleCropToInsideImage];
    [self snapCropInsideImage];

    [self displayCropScaled];
    [self displayCropCentered];
    [self updateMask];
}

- (void)adjustCropRotation:(CGFloat)deltaAngleInRadians {
    [self.gridView setTransform:CGAffineTransformRotate(self.gridView.transform, deltaAngleInRadians)];

    [self scaleCropToInsideImage];
    [self snapCropInsideImage];
    
    [self displayCropScaled];
    [self displayCropUnrotated:-deltaAngleInRadians];
    [self displayCropCentered];
    [self updateMask];
}

#pragma mark - gesture support

- (void)handlePan:(UIPanGestureRecognizer *)recognizer {
    UIView *piece = [recognizer view];
    if ([recognizer state] == UIGestureRecognizerStateBegan || [recognizer state] == UIGestureRecognizerStateChanged) {
        // scale the translation so the effect seems smooth and not tiny
        CGPoint translation = [recognizer translationInView:[piece superview]];
        translation.x /= xscaleFromTransform(self.gridView.transform) * xscaleFromTransform(self.transform);
        translation.y /= yscaleFromTransform(self.gridView.transform) * yscaleFromTransform(self.transform);
        
        if (self.autoDisplayEnabled) {
            // invert the signs, so that the UI seems to move the image, not the crop
            translation.x = -translation.x;
            translation.y = -translation.y;
        }
        
        [self adjustCropPosition:translation];
        [recognizer setTranslation:CGPointZero inView:[piece superview]];
    }
}

- (IBAction)handleDoubleTap:(UITapGestureRecognizer *)recognizer {
    [self toggleAutoDisplay];
}

- (IBAction)handlePinch:(UIPinchGestureRecognizer *)recognizer {
    if (self.gridView.overlayType == kCropOverlayRuleOfThirds) {
        CGFloat newScale = recognizer.scale;
    
        if (self.autoDisplayEnabled) {
            // invert the scale, so that the UI seems to be changing the image, not the crop
            newScale = 1/ newScale;
        }
    
        [self adjustCropScale:newScale];
        [recognizer setScale:1];
    }
}

- (IBAction)handleRotation:(UIRotationGestureRecognizer *)recognizer {
    if (self.gridView.overlayType == kCropOverlayGrid) {
        CGFloat deltaAngle = recognizer.rotation;
        if (self.autoDisplayEnabled) {
            // invert the delta, so that the UI seems to be changing the image, not the crop
            deltaAngle = -deltaAngle;
        }

        CGFloat maxAngle = degreesToRadians(44.9);
        CGFloat minAngle = degreesToRadians(-44.9);
        CGFloat gridAngle = calcLimitedRotationValue(rotationFromTransform(self.gridView.transform), [self getImageOrientation]);
        if (gridAngle + deltaAngle < minAngle) {
            deltaAngle = minAngle - gridAngle;
        } else if (gridAngle + deltaAngle > maxAngle) {
            deltaAngle = maxAngle - gridAngle;
        }
        [self adjustCropRotation:deltaAngle];
        
        [recognizer setRotation:0.0];
        [self.delegate rotationAngleChanged:self];
    }
}

#pragma mark - special transform functions

CGAffineTransform applyOrientationToTransform(UIImageOrientation orientation, CGAffineTransform transform, BOOL bAllowFlips) {
    CGAffineTransform returnT = transform;
    CGFloat adjAngle = 0.0;
    CGFloat adjScaleX = 1.0;
    CGFloat adjScaleY = 1.0;
    
    switch (orientation) {
        case UIImageOrientationUp:
            break;
        case UIImageOrientationUpMirrored:
            adjScaleX = -1.0;
            break;
        case UIImageOrientationDownMirrored:
            adjScaleY = -1.0;
            break;
        case UIImageOrientationDown:
            adjAngle = 180.0;
            break;
        case UIImageOrientationRight:
            adjAngle = 90.0;
            break;
        case UIImageOrientationRightMirrored:
            adjAngle = -90.0;
            adjScaleY = -1;
            break;
        case UIImageOrientationLeft:
            adjAngle = -90.0;
            break;
        case UIImageOrientationLeftMirrored:
            adjAngle = 90.0;
            adjScaleY = -1;
            break;
        default:
            break;
    }
    
    returnT = CGAffineTransformRotate(returnT, degreesToRadians(adjAngle));
    if (bAllowFlips)
        returnT = CGAffineTransformScale(returnT, adjScaleX, adjScaleY);
    
    return returnT;
}

CGAffineTransform adjustTranslationsForOrientation(UIImageOrientation orientation, CGAffineTransform transform, BOOL bFlipFlag) {
    CGAffineTransform returnT = transform;

    switch (orientation) {
        case UIImageOrientationUp:
            returnT.tx = (bFlipFlag) ? -transform.tx : transform.tx;
            returnT.ty = (bFlipFlag) ? -transform.ty : transform.ty;
            break;
        case UIImageOrientationUpMirrored:
        case UIImageOrientationDownMirrored:
            returnT.tx = (bFlipFlag) ? -transform.tx : transform.tx;
            returnT.ty = (bFlipFlag) ? -transform.ty : transform.ty;
            break;
        case UIImageOrientationDown:
            returnT.tx = (bFlipFlag) ? transform.tx : -transform.tx;
            returnT.ty = (bFlipFlag) ? transform.ty : -transform.ty;
            break;
        case UIImageOrientationRight:
        case UIImageOrientationLeftMirrored:
            returnT.tx = (bFlipFlag) ? -transform.ty : transform.ty;
            returnT.ty = (bFlipFlag) ? transform.tx : -transform.tx;
            break;
        case UIImageOrientationLeft:
        case UIImageOrientationRightMirrored:
            returnT.tx = (bFlipFlag) ? transform.ty : -transform.ty;
            returnT.ty = (bFlipFlag) ? -transform.tx : transform.tx;
            break;
        default:
            break;
    }
    
    return returnT;
}

- (CGPoint) calcGridCenterPoint {
    CGPoint pt1 = transformedTopLeft(self.gridView);
    pt1 = [self convertPoint:pt1 toView:self.maskView];
    CGPoint pt2 = transformedTopRight(self.gridView);
    pt2 = [self convertPoint:pt2 toView:self.maskView];
    CGPoint pt3 = transformedBottomRight(self.gridView);
    pt3 = [self convertPoint:pt3 toView:self.maskView];
    CGPoint pt4 = transformedBottomLeft(self.gridView);
    pt4 = [self convertPoint:pt4 toView:self.maskView];
    
    CGRect gridRect;
    UIImageOrientation orientation = [self getImageOrientation];
    switch (orientation) {
        case UIImageOrientationUp:
        case UIImageOrientationUpMirrored:
        case UIImageOrientationDownMirrored:
            gridRect.origin = pt1;
            gridRect.size.width = pt2.x - gridRect.origin.x;
            gridRect.size.height = pt4.y - gridRect.origin.y;
            break;
        case UIImageOrientationDown:
            gridRect.origin = pt3;
            gridRect.size.width = pt4.x - gridRect.origin.x;
            gridRect.size.height = pt2.y - gridRect.origin.y;
            break;
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            gridRect.origin = pt4;
            gridRect.size.width = pt1.x - gridRect.origin.x;
            gridRect.size.height = pt3.y - gridRect.origin.y;
            break;
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
            gridRect.origin = pt2;
            gridRect.size.width = pt3.x - gridRect.origin.x;
            gridRect.size.height = pt1.y - gridRect.origin.y;
            break;
        default:
            break;
    }
//    NSLog(@"gridRect = (%f, %f) %fx%f", gridRect.origin.x, gridRect.origin.y, gridRect.size.width, gridRect.size.height);
    
    CGPoint retPoint;
    retPoint.x = gridRect.origin.x + gridRect.size.width / 2;
    retPoint.y = gridRect.origin.y + gridRect.size.height / 2;
    
    return retPoint;
}

@end
