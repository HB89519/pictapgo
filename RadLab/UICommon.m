//
//  UICommon.m
//  RadLab
//
//  Created by Geoff Scott on 2/5/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import "UICommon.h"
#import <QuartzCore/QuartzCore.h>

void addPinstripingToView(UIView *view) {
    view.layer.backgroundColor = [[UIColor colorWithPatternImage:[UIImage imageNamed:@"Background_Scene.png"]] CGColor];
}

void addMaskToToolBar(UIView *toolBar) {
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.frame = toolBar.bounds;
    
    CGMutablePathRef smileyPath = CGPathCreateMutable();
    CGPathMoveToPoint(smileyPath, NULL, toolBar.bounds.origin.x, toolBar.bounds.origin.y);
    CGPathAddLineToPoint(smileyPath, NULL, toolBar.bounds.origin.x, toolBar.bounds.origin.y + toolBar.bounds.size.height);
    CGPathAddLineToPoint(smileyPath, NULL, toolBar.bounds.origin.x + toolBar.bounds.size.width, toolBar.bounds.origin.y + toolBar.bounds.size.height);
    CGPathAddLineToPoint(smileyPath, NULL, toolBar.bounds.origin.x + toolBar.bounds.size.width, toolBar.bounds.origin.y);
    CGFloat cp1x = toolBar.bounds.origin.x + toolBar.bounds.size.width * 2 / 3;
    CGFloat cp2x = toolBar.bounds.origin.x + toolBar.bounds.size.width / 3;
    CGFloat cpy = toolBar.bounds.origin.y + toolBar.bounds.size.height / 3;
    CGPathAddCurveToPoint(smileyPath, NULL, cp1x, cpy, cp2x, cpy, toolBar.bounds.origin.x, toolBar.bounds.origin.y);
    
    maskLayer.path = smileyPath;
    toolBar.layer.mask = maskLayer;
    toolBar.layer.masksToBounds = YES;
    CGPathRelease(smileyPath);
}

void setPreviewStylingForView(UIImageView *imageView) {
    imageView.layer.shadowOpacity = 0.85;
    imageView.layer.shadowRadius = 1.5;
    imageView.layer.shadowOffset = CGSizeMake(0, 1.5);
}

float imageDiagonal(CGSize sz) {
    return sqrt(sz.width * sz.width + sz.height * sz.height);
}

float scaledRadius(CGSize sz, float radiusPercentage) {
    const float diagonal = imageDiagonal(sz);
    const float radius = diagonal * radiusPercentage;
    return radius;
}

UIImage* blurImage(UIImage* srcImage) {
    CIContext *context = [CIContext contextWithOptions:nil];
    CIImage *inputImage = [[CIImage alloc] initWithCGImage:srcImage.CGImage];
    NSNumber *inputRadius = [NSNumber numberWithFloat:0.01];
    
    const CGSize inputSize = inputImage.extent.size;
    CGSize sz = inputImage.extent.size;
    CGFloat preScale = 1.0, postScale = 1.0;
    CGFloat actualRadius = scaledRadius(sz, inputRadius.floatValue);
    while (sz.width > 1024 || sz.height > 1024 || actualRadius > 100.0) {
        sz.width /= 2.0;
        sz.height /= 2.0;
        preScale /= 2.0;
        postScale *= 2.0;
        actualRadius /= 2.0;
    }
    
    // Extend the canvas by duplicating the edge pixels
    CIFilter* extend = [CIFilter filterWithName:@"CIAffineClamp"];
    [extend setDefaults];
    [extend setValue:inputImage forKey:@"inputImage"];
    [extend setValue:[NSValue valueWithBytes:&CGAffineTransformIdentity
                                    objCType:@encode(CGAffineTransform)] forKey:@"inputTransform"];
    
    CIImage* canvas = extend.outputImage;
    if (sz.width != inputSize.width || sz.height != inputSize.height) {
        CGAffineTransform downscale = CGAffineTransformMakeScale(preScale, preScale);
        canvas = [canvas imageByApplyingTransform:downscale];
    }

    CIFilter* filter = [CIFilter filterWithName:@"CIGaussianBlur"];
    [filter setDefaults];
    [filter setValue:canvas forKey:@"inputImage"];
    [filter setValue:[NSNumber numberWithFloat:actualRadius] forKey:@"inputRadius"];
    
    
    CIImage* upsize = filter.outputImage;
    if (inputSize.width != sz.width || inputSize.height != sz.height) {
        CGAffineTransform upscale = CGAffineTransformMakeScale(postScale, postScale);
        upsize = [upsize imageByApplyingTransform:upscale];
    }
    CIImage* crop = [upsize imageByCroppingToRect:CGRectMake(0, 0, inputSize.width, inputSize.height)];
    CGImageRef cgImage = [context createCGImage:crop fromRect:[crop extent]];
    
    UIImage *retImage = [[UIImage alloc] initWithCGImage:cgImage];
    return retImage;
}

void setupSmileySlider(PTGSlider *slider) {
	[slider setThumbImage:[UIImage imageNamed:@"Slider_ThumbDisabled.png"] forState:UIControlStateDisabled];
	[slider setThumbImage:[UIImage imageNamed:@"Slider_Thumb.png"] forState:UIControlStateNormal];
	[slider setMaximumTrackImage:[UIImage imageNamed:@"SliderTrack_MaxDisabled.png"] forState:UIControlStateDisabled];
	[slider setMaximumTrackImage:[UIImage imageNamed:@"SliderTrack_Max.png"] forState:UIControlStateNormal];
	[slider setMinimumTrackImage:[UIImage imageNamed:@"SliderTrack_MinDisabled.png"] forState:UIControlStateDisabled];
	[slider setMinimumTrackImage:[UIImage imageNamed:@"SliderTrack_Min.png"] forState:UIControlStateNormal];
}

void setupStraightSlider(PTGSlider *slider) {
	[slider setThumbImage:[UIImage imageNamed:@"Slider_ThumbDisabled.png"] forState:UIControlStateDisabled];
	[slider setThumbImage:[UIImage imageNamed:@"Slider_Thumb.png"] forState:UIControlStateNormal];
	[slider setMaximumTrackImage:[UIImage imageNamed:@"SliderStraight_Max.png"] forState:UIControlStateDisabled];
	[slider setMaximumTrackImage:[UIImage imageNamed:@"SliderStraight_Max.png"] forState:UIControlStateNormal];
	[slider setMinimumTrackImage:[UIImage imageNamed:@"SliderStraight_Min.png"] forState:UIControlStateDisabled];
	[slider setMinimumTrackImage:[UIImage imageNamed:@"SliderStraight_Min.png"] forState:UIControlStateNormal];
}

UIInterfaceOrientation currentDeviceOrientation(void) {
    return [UIApplication sharedApplication].statusBarOrientation;
}

CGRect currentScreenRect(void) {
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    switch (currentDeviceOrientation()) {
        case UIInterfaceOrientationLandscapeLeft:
        case UIInterfaceOrientationLandscapeRight:
        {
            CGRect tempRect = screenRect;
            screenRect.origin.x = tempRect.origin.y;
            screenRect.origin.y = tempRect.origin.x;
            screenRect.size.width = tempRect.size.height;
            screenRect.size.height = tempRect.size.width;
        }
        break;
        
        case UIInterfaceOrientationPortrait:
        case UIInterfaceOrientationPortraitUpsideDown:
        default:
            // screenRect is already correct
            break;
    }
    return screenRect;
}

float degreesToRadians(float degrees) {
    return degrees * M_PI / 180.0;
}

float radiansToDegrees(float radians) {
    return radians * 180.0 / M_PI;
}

// calc new angle mapping current angle to be between -45 and 45 degrees
float calcLimitedRotationValue(float curRadians, UIImageOrientation orientation) {
    CGFloat retAngle = radiansToDegrees(curRadians);
    
    if (orientation == UIImageOrientationUp
        || orientation == UIImageOrientationDown
        || orientation == UIImageOrientationUpMirrored
        || orientation == UIImageOrientationDownMirrored) {
        if (retAngle > 45.0) {
            retAngle = retAngle - 180.0;
        } else if (retAngle < -45.0) {
            retAngle = 180.0 + retAngle;
        }
    } else if (orientation == UIImageOrientationLeft
               || orientation == UIImageOrientationRight
               || orientation == UIImageOrientationLeftMirrored
               || orientation == UIImageOrientationRightMirrored) {
        if (retAngle >= 45.0) {
            retAngle = retAngle - 90.0;
        } else if (retAngle <= -45.0) {
            retAngle = 90.0 + retAngle;
        }
    }
    
    return degreesToRadians(retAngle);
}

// transform utilities
// based on http://www.informit.com/articles/article.aspx?p=1951182

CGFloat xscaleFromTransform(CGAffineTransform transform) {
    return sqrt(transform.a * transform.a + transform.c * transform.c);
}

CGFloat yscaleFromTransform(CGAffineTransform transform) {
    return sqrt(transform.b * transform.b + transform.d * transform.d);
}

CGFloat rotationFromTransform(CGAffineTransform transform) {
    return atan2f(transform.b, transform.a);
}

CGFloat txFromTransform(CGAffineTransform transform) {
    return transform.tx;
}

CGFloat tyFromTransform(CGAffineTransform transform) {
    return transform.ty;
}

CGFloat determinantFromTransform(CGAffineTransform transform) {
    return (transform.a * transform.d - transform.b * transform.c);
}

UIImageOrientation imageOrientationFromTransform(CGAffineTransform transform) {
    UIImageOrientation retOrient = UIImageOrientationUp;    
    CGFloat det = determinantFromTransform(transform);
    CGFloat orientAngle = radiansToDegrees(rotationFromTransform(transform));
    
    if (orientAngle == 0) {
        retOrient = (det < 0.0) ? UIImageOrientationDownMirrored : UIImageOrientationUp;
    } else if (orientAngle == 90) {
        retOrient = (det < 0.0) ? UIImageOrientationLeftMirrored : UIImageOrientationRight;
    } else if (orientAngle == -90) {
        retOrient = (det < 0.0) ? UIImageOrientationRightMirrored : UIImageOrientationLeft;
    } else if (orientAngle == 180 || orientAngle == -180) {
        retOrient = (det < 0.0) ? UIImageOrientationUpMirrored : UIImageOrientationDown;
    }

    return retOrient;
}

// coordinate utilities
// based on http://www.informit.com/articles/article.aspx?p=1951182

CGPoint offsetPointToParentCoordinates(CGPoint aPoint, UIView *view) {
    return CGPointMake(aPoint.x + view.center.x,
                       aPoint.y + view.center.y);
}

CGPoint pointInViewCenterTerms(CGPoint aPoint, UIView *view) {
    return CGPointMake(aPoint.x - view.center.x,
                       aPoint.y - view.center.y);
}

CGPoint pointInTransformedView(CGPoint aPoint, UIView *view) {
    CGPoint offsetItem = pointInViewCenterTerms(aPoint, view);
    CGPoint updatedItem = CGPointApplyAffineTransform(offsetItem, view.transform);
    CGPoint finalItem = offsetPointToParentCoordinates(updatedItem, view);
    return finalItem;
}

CGRect originalFrame(UIView *view) {
    CGAffineTransform currentTransform = view.transform;
    view.transform = CGAffineTransformIdentity;
    CGRect originalFrame = view.frame;
    view.transform = currentTransform;
    
    return originalFrame;
}

// These four methods return the positions of view elements
// with respect to the current transform
// based on http://www.informit.com/articles/article.aspx?p=1951182

CGPoint transformedTopLeft(UIView *view) {
    CGRect frame = originalFrame(view);
    CGPoint point = frame.origin;
    return pointInTransformedView(point, view);
}

CGPoint transformedTopRight(UIView *view) {
    CGRect frame = originalFrame(view);
    CGPoint point = frame.origin;
    point.x += frame.size.width;
    return pointInTransformedView(point, view);
}

CGPoint transformedBottomRight(UIView *view) {
    CGRect frame = originalFrame(view);
    CGPoint point = frame.origin;
    point.x += frame.size.width;
    point.y += frame.size.height;
    return pointInTransformedView(point, view);
}

CGPoint transformedBottomLeft(UIView *view) {
    CGRect frame = originalFrame(view);
    CGPoint point = frame.origin;
    point.y += frame.size.height;
    return pointInTransformedView(point, view);
}

CGFloat aspectRatioFromView(UIView *view) {
    CGFloat newWidth = view.bounds.size.width * xscaleFromTransform(view.transform);
    CGFloat newHeight = view.bounds.size.height * yscaleFromTransform(view.transform);
    
    return newWidth / newHeight;
}

CGRect adjustRectToAspectRatio(CGRect sourceRect, CGFloat newRatio) {
    CGRect newBounds = sourceRect;
    
    if (newRatio > 1.0) {
        newBounds.size.width = sourceRect.size.width;
        newBounds.size.height = sourceRect.size.width / newRatio;
        
        if (newBounds.size.height > sourceRect.size.height) {
            newBounds.size.width = newBounds.size.width * sourceRect.size.height / newBounds.size.height;
            newBounds.size.height = sourceRect.size.height;
        }
        
        newBounds.origin.x = sourceRect.origin.x + (sourceRect.size.width - newBounds.size.width) / 2;
        newBounds.origin.y = sourceRect.origin.y + (sourceRect.size.height - newBounds.size.height) / 2;
    } else {
        newBounds.size.width = sourceRect.size.height * newRatio;
        newBounds.size.height = sourceRect.size.height;
        
        if (newBounds.size.width > sourceRect.size.width) {
            newBounds.size.height = newBounds.size.height * sourceRect.size.width / newBounds.size.width;
            newBounds.size.width = sourceRect.size.width;
        }
        
        newBounds.origin.x = sourceRect.origin.x + (sourceRect.size.width - newBounds.size.width) / 2;
        newBounds.origin.y = sourceRect.origin.y + (sourceRect.size.height - newBounds.size.height) / 2;
    }
    
    return newBounds;
}

CGRect adjustRectToAspectRatioWithOrientation(CGRect sourceRect, CGFloat newRatio, UIImageOrientation orientation) {
    CGRect cropRect = adjustRectToAspectRatio(sourceRect, newRatio);

    if (orientation == UIImageOrientationRight || orientation == UIImageOrientationRightMirrored
        || orientation == UIImageOrientationLeft || orientation == UIImageOrientationLeftMirrored) {
        CGRect tempRect = cropRect;
        cropRect.origin.x = tempRect.origin.y;
        cropRect.origin.y = tempRect.origin.x;
        cropRect.size.width = tempRect.size.height;
        cropRect.size.height = tempRect.size.width;
    }
    
    return cropRect;
}

// copied from StackOverflow (?) as being useful, but not used anywhere yet
void setAnchorPoint(CGPoint anchorPoint, UIView *view) {
    CGPoint newPoint = CGPointMake(view.bounds.size.width * anchorPoint.x, view.bounds.size.height * anchorPoint.y);
    CGPoint oldPoint = CGPointMake(view.bounds.size.width * view.layer.anchorPoint.x, view.bounds.size.height * view.layer.anchorPoint.y);
    
    newPoint = CGPointApplyAffineTransform(newPoint, view.transform);
    oldPoint = CGPointApplyAffineTransform(oldPoint, view.transform);
    
    CGPoint position = view.layer.position;
    
    position.x -= oldPoint.x;
    position.x += newPoint.x;
    
    position.y -= oldPoint.y;
    position.y += newPoint.y;
    
    view.layer.position = position;
    view.layer.anchorPoint = anchorPoint;
}

NSInteger rotationDegrees(UIImageOrientation orientation) {
    switch (orientation) {
        case UIImageOrientationUp: return 0;
        case UIImageOrientationDown: return 180;
        case UIImageOrientationLeft: return 270;
        case UIImageOrientationRight: return 90;
        default: return 0;
    }
}

BOOL transposedOrientation(UIImageOrientation orientation) {
    switch (orientation) {
        case UIImageOrientationLeft:
        case UIImageOrientationRight:
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRightMirrored:
            return YES;
        default:
            return NO;
    }
}

void transposeSize(CGSize* sz) {
    CGFloat tmp = sz->width;
    sz->width = sz->height;
    sz->height = tmp;
}
