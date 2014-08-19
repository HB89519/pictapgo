//
//  UICommon.h
//  RadLab
//
//  Created by Geoff Scott on 2/5/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PTGSlider.h"

// add pinstring to the background layer of a view
void addPinstripingToView(UIView *view);

// add a mask to a toolBar for the smile
void addMaskToToolBar(UIView *toolBar);

// add styling around preview image
void setPreviewStylingForView(UIImageView *imageView);

// blur an image for background use (iOS7)
UIImage* blurImage(UIImage* srcImage);

// setup smiley slider artwork
void setupSmileySlider(PTGSlider *slider);

// setup straight slider artwork
void setupStraightSlider(PTGSlider *slider);

// get the device orientation (not as obvious as it should be
UIInterfaceOrientation currentDeviceOrientation(void);

// get the rect of the current device's main screen with orientation considered
CGRect currentScreenRect(void);

// convert degrees to radians
float degreesToRadians(float degrees);

// convert radians to degrees
float radiansToDegrees(float radians);

// calc new angle mapping current angle to be between -45 and 45 degrees
float calcLimitedRotationValue(float curRadians, UIImageOrientation orientation);

// useful helpers for transforms
CGFloat xscaleFromTransform(CGAffineTransform transform);
CGFloat yscaleFromTransform(CGAffineTransform transform);
CGFloat rotationFromTransform(CGAffineTransform transform);
CGFloat txFromTransform(CGAffineTransform transform);
CGFloat tyFromTransform(CGAffineTransform transform);
CGFloat determinantFromTransform(CGAffineTransform transform);
UIImageOrientation imageOrientationFromTransform(CGAffineTransform transform);

// useful helpers for transformed views
CGPoint offsetPointToParentCoordinates(CGPoint aPoint, UIView *view);
CGPoint pointInViewCenterTerms(CGPoint aPoint, UIView *view);
CGPoint pointInTransformedView(CGPoint aPoint, UIView *view);
CGRect originalFrame(UIView *view);
CGPoint transformedTopLeft(UIView *view);
CGPoint transformedTopRight(UIView *view);
CGPoint transformedBottomRight(UIView *view);
CGPoint transformedBottomLeft(UIView *view);

// calc aspect ratio from a potentially rotated & scaled view
CGFloat aspectRatioFromView(UIView *view);

// scale a rect to match new aspect ratio, keeping new rect inside source rect
CGRect adjustRectToAspectRatio(CGRect sourceRect, CGFloat newRatio);

// scale a rect to match new aspect ratio, keeping new rect inside source rect
CGRect adjustRectToAspectRatioWithOrientation(CGRect sourceRect, CGFloat newRatio, UIImageOrientation orientation);

// set the anchor point for a view
void setAnchorPoint(CGPoint anchorPoint, UIView *view);

// helper functions for imageOrientation
NSInteger rotationDegrees(UIImageOrientation orientation);
BOOL transposedOrientation(UIImageOrientation orientation);
void transposeSize(CGSize* sz);