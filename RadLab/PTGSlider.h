//
//  PTGSlider.h
//  PathSliderApp
//
//  Created by Geoff Scott on 1/11/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PTGSlider : UIControl

@property (nonatomic, assign) float minimumValue;
@property (nonatomic, assign) float maximumValue;
@property (nonatomic, assign) float value;
@property (nonatomic, assign) float defaultValue;
@property (nonatomic, getter=isContinuous) BOOL continuous;
@property (nonatomic, assign) BOOL resetsToDefault;
@property (nonatomic, copy) NSString *value_min;
@property (nonatomic, copy) NSString *value_max;
@property (nonatomic, copy) NSString *value_cur;

- (void)setValue:(float)value animated:(BOOL)animated;
- (void)reset;

- (void)setThumbImage:(UIImage *)image forState:(UIControlState)state;
- (UIImage *)thumbImageForState:(UIControlState)state;
- (void)setMinimumTrackImage:(UIImage *)image forState:(UIControlState)state;
- (UIImage *)minimumTrackImageForState:(UIControlState)state;
- (void)setMaximumTrackImage:(UIImage *)image forState:(UIControlState)state;
- (UIImage *)maximumTrackImageForState:(UIControlState)state;

@end
