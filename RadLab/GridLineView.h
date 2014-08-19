//
//  GridLineView.h
//  RadLab
//
//  Created by Geoff Scott on 3/14/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum {
    kCropOverlayRuleOfThirds = 0,
    kCropOverlayGrid,
} CropOverlayType;

@interface GridLineView : UIView

@property (nonatomic, assign) CGFloat initAspectRatio;
@property (nonatomic, assign) CGFloat curAspectRatio;
@property (nonatomic, assign) CGRect constrainingRect;
@property (nonatomic, assign) CropOverlayType overlayType;

- (void)resetAspectRatio;

@end
