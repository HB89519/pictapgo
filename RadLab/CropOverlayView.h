//
//  CropOverlayView.h
//  RadLab
//
//  Created by Geoff Scott on 3/7/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GridLineView.h"

@protocol CropOverlayViewDelegate;

@interface CropOverlayView : UIView

@property (weak, nonatomic) id<CropOverlayViewDelegate> delegate;
@property (nonatomic, weak) UIView *maskView;

- (CGAffineTransform)getCropTransform;
- (UIImageOrientation)getImageOrientation;
- (CGSize)getCropSourceImageSize;
- (CGFloat)getCropAspectRatio;
- (CGFloat)getRotationAngle;

- (void)setUpWithImage:(UIImage *)image
   andImageOrientation:(UIImageOrientation)orientation
      andCropTransform:(CGAffineTransform)cropTransform
     andCropAspectRatio:(CGFloat)aspectRatio;
- (void)setOverlayType:(CropOverlayType) newType;
- (void)updateMask;
- (void)displayCropCentered;
- (void)adjustToNewFrame:(CGRect)parentFrame;

- (void)resetAllTransforms;

- (BOOL)isAutoDisplayEnabled;
- (void)toggleAutoDisplay;

- (void)setAspectRatioWithWidth:(CGFloat)ratio_w andHeight:(CGFloat)ratio_h;
- (void)setAspectRatio:(CGFloat)newRatio;

- (void)doFlipImageHorizontal;
- (void)doFlipImageVertical;
- (void)doRotateImage90Right;
- (void)doRotateImage90Left;

- (void)adjustCropPosition:(CGPoint)deltaOffset;
- (void)adjustCropScale:(CGFloat)newScale;
- (void)adjustCropRotation:(CGFloat)deltaAngleInRadians;

@end

@protocol CropOverlayViewDelegate <NSObject>

- (void)rotationAngleChanged:(CropOverlayView *)view;

@end