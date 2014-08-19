//
//  PTGSlider.m
//  PathSliderApp
//
//  Created by Geoff Scott on 1/11/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import "PTGSlider.h"
#import <QuartzCore/QuartzCore.h>

@interface PTGSlider ()
{
	UIImageView *_thumbImageView;
	UIImage *_thumbImageNormal;
	UIImage *_thumbImageHighlighted;
	UIImage *_thumbImageDisabled;
    
    UIImageView *_minimumTrackImageView;
    UIImage *_minTrackImageNormal;
    UIImage *_minTrackImageHighlighted;
    UIImage *_minTrackImageDisabled;
    
    UIImageView *_maximumTrackImageView;
    UIImage *_maxTrackImageNormal;
    UIImage *_maxTrackImageHighlighted;
    UIImage *_maxTrackImageDisabled;
    
	CGPoint _touchOrigin;
    CGPoint _lastTouchPt;
    float _outOfBoundsMod;
	BOOL _canReset;
}

@end

@implementation PTGSlider

@synthesize minimumValue = _minimumValue;
@synthesize maximumValue = _maximumValue;
@synthesize value = _value;
@synthesize defaultValue = _defaultValue;
@synthesize continuous = _continuous;
@synthesize resetsToDefault = _resetsToDefault;
@synthesize value_min = _value_min;
@synthesize value_max = _value_max;
@synthesize value_cur = _value_cur;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
	if ((self = [super initWithCoder:aDecoder]))
	{
		[self commonInit];
	}
	return self;
}

- (void)commonInit {
	self.minimumValue = 0.0;
	self.maximumValue = 1.0;
	self.value = 0.5;
    self.defaultValue = 0.0;
	self.continuous = YES;
    self.resetsToDefault = YES;
    _outOfBoundsMod = 0.0;
    
    _minimumTrackImageView = [[UIImageView alloc] initWithFrame:self.bounds];
    [_minimumTrackImageView setContentMode:UIViewContentModeScaleAspectFit];
    [self addSubview:_minimumTrackImageView];
    
    _maximumTrackImageView = [[UIImageView alloc] initWithFrame:self.bounds];
    [_maximumTrackImageView setContentMode:UIViewContentModeScaleAspectFit];
    [self addSubview:_maximumTrackImageView];
    
	_thumbImageView = [[UIImageView alloc] initWithFrame:self.bounds];
    [_thumbImageView setContentMode:UIViewContentModeScaleAspectFit];
	[self addSubview:_thumbImageView];
}

- (void)awakeFromNib {
    [super awakeFromNib];
    
    // set value params, if available
    if ([self.value_min floatValue] != self.minimumValue
        && self.value_min.length > 0) {
        self.minimumValue = [self.value_min floatValue];
    }
    if ([self.value_max floatValue] != self.maximumValue
        && self.value_max.length > 0) {
        self.maximumValue = [self.value_max floatValue];
    }
    if ([self.value_cur floatValue] != self.value
        && self.value_cur.length > 0) {
        [self setValue:[self.value_cur floatValue]];
        self.defaultValue = self.value;
    }
}

- (void)setValue:(float)value {
    _value = value;
    [self syncThumbToValue];
    [self syncTrackToValue];
}

- (void)setValue:(float)value animated:(BOOL)animated {
    [self setValue:value];
}

- (void)reset {
    [self setValue:self.defaultValue];
}

- (void)setThumbImage:(UIImage *)image forState:(UIControlState)state {
    float newWidth = self.frame.size.width;
    float newHeight = self.frame.size.height;
    
    if (image.size.height > newHeight) {
        float newScale = newHeight / image.size.height;
        newWidth = image.size.width * newScale;
    }
    
    CGRect imageFrame = CGRectMake(_thumbImageView.frame.origin.x, _thumbImageView.frame.origin.y, newWidth, newHeight);
    [_thumbImageView setFrame:imageFrame];

	if (state == UIControlStateNormal) {
		if (image != _thumbImageNormal) {
			_thumbImageNormal = image;
            
			if (self.state == UIControlStateNormal) {
				_thumbImageView.image = image;
			}
		}
	}
    
	if (state & UIControlStateHighlighted) {
		if (image != _thumbImageHighlighted) {
			_thumbImageHighlighted = image;
            
			if (self.state & UIControlStateHighlighted) {
				_thumbImageView.image = image;
            }
		}
	}
    
	if (state & UIControlStateDisabled) {
		if (image != _thumbImageDisabled) {
			_thumbImageDisabled = image;
            
			if (self.state & UIControlStateDisabled) {
				_thumbImageView.image = image;
            }
		}
	}

    [self syncThumbToValue];
}

- (UIImage *)thumbImageForState:(UIControlState)state {
    UIImage *retImage = _thumbImageNormal;
    
    if (state & UIControlStateHighlighted && _thumbImageHighlighted)
		retImage = _thumbImageHighlighted;
	else if (state & UIControlStateDisabled && _thumbImageDisabled)
		retImage = _thumbImageDisabled;
    
    return retImage;
}

- (void)setMinimumTrackImage:(UIImage *)image forState:(UIControlState)state {
    CGRect imageFrame = CGRectMake(_minimumTrackImageView.frame.origin.x, _minimumTrackImageView.frame.origin.y, self.frame.size.width, self.frame.size.height);
    [_minimumTrackImageView setFrame:imageFrame];

	if (state == UIControlStateNormal) {
		if (image != _minTrackImageNormal) {
			_minTrackImageNormal = image;
            
			if (self.state == UIControlStateNormal) {
				_minimumTrackImageView.image = image;
			}
		}
	}
    
	if (state & UIControlStateHighlighted) {
		if (image != _minTrackImageHighlighted) {
			_minTrackImageHighlighted = image;
            
			if (self.state & UIControlStateHighlighted) {
				_minimumTrackImageView.image = image;
            }
		}
	}
    
	if (state & UIControlStateDisabled) {
		if (image != _minTrackImageDisabled) {
			_minTrackImageDisabled = image;
            
			if (self.state & UIControlStateDisabled) {
				_minimumTrackImageView.image = image;
            }
		}
	}

    // don't need to sync track here, because only affects maxTrackView
}

- (UIImage *)minimumTrackImageForState:(UIControlState)state {
    UIImage *retImage = _minTrackImageNormal;
    
    if (state & UIControlStateHighlighted && _minTrackImageHighlighted)
		retImage = _minTrackImageHighlighted;
	else if (state & UIControlStateDisabled && _minTrackImageDisabled)
		retImage = _minTrackImageDisabled;
    
    return retImage;
}

- (void)setMaximumTrackImage:(UIImage *)image forState:(UIControlState)state {
    CGRect imageFrame = CGRectMake(_maximumTrackImageView.frame.origin.x, _maximumTrackImageView.frame.origin.y, self.frame.size.width, self.frame.size.height);
    [_maximumTrackImageView setFrame:imageFrame];

	if (state == UIControlStateNormal) {
		if (image != _maxTrackImageNormal) {
			_maxTrackImageNormal = image;
            
			if (self.state == UIControlStateNormal) {
				_maximumTrackImageView.image = image;
			}
		}
	}
    
	if (state & UIControlStateHighlighted) {
		if (image != _maxTrackImageHighlighted) {
			_maxTrackImageHighlighted = image;
            
			if (self.state & UIControlStateHighlighted) {
				_maximumTrackImageView.image = image;
            }
		}
	}
    
	if (state & UIControlStateDisabled) {
		if (image != _maxTrackImageDisabled) {
			_maxTrackImageDisabled = image;
            
			if (self.state & UIControlStateDisabled) {
				_maximumTrackImageView.image = image;
            }
		}
	}
    
    [self syncTrackToValue];
}

- (UIImage *)maximumTrackImageForState:(UIControlState)state {
    UIImage *retImage = _maxTrackImageNormal;
    
    if (state & UIControlStateHighlighted && _maxTrackImageHighlighted)
		retImage = _maxTrackImageHighlighted;
	else if (state & UIControlStateDisabled && _maxTrackImageDisabled)
		retImage = _maxTrackImageDisabled;
    
    return retImage;
}

- (float)valueForPosition:(CGPoint)point {
    float retval = (self.maximumValue - self.minimumValue) * (point.x - self.bounds.origin.x)/ (self.bounds.size.width - _thumbImageView.bounds.size.width) + self.minimumValue;
    
    // constrain value to min & max values
    if (retval > self.maximumValue)
        retval = self.maximumValue;
    else if (retval < self.minimumValue)
        retval = self.minimumValue;
    
    return retval;
}

- (CGPoint)positionForValue:(float)value {
    CGPoint retPoint = CGPointMake(0.0, self.bounds.origin.y);
    retPoint.x = (self.bounds.size.width - _thumbImageView.frame.size.width) * (value - self.minimumValue) / (self.maximumValue - self.minimumValue) + self.bounds.origin.x;
    
    // constrain return point to be inside the bounds
    if (retPoint.x > self.bounds.origin.x + self.bounds.size.width)
        retPoint.x = self.bounds.origin.x + self.bounds.size.width;
    else if (retPoint.x < self.bounds.origin.x)
        retPoint.x = self.bounds.origin.x;
    
    if (retPoint.y > self.bounds.origin.y + self.bounds.size.height)
        retPoint.y = self.bounds.origin.y + self.bounds.size.height;
    else if (retPoint.y < self.bounds.origin.y)
        retPoint.y = self.bounds.origin.y;

    return retPoint;
}

- (void)syncThumbToValue {
    CGPoint imagePt = [self positionForValue:self.value];
    CGRect imageFrame = CGRectMake(imagePt.x, imagePt.y, _thumbImageView.frame.size.width, _thumbImageView.frame.size.height);
    [_thumbImageView setFrame:imageFrame];
}

- (void)syncTrackToValue {
    CGPoint valuePt = [self positionForValue:self.value];
    CGRect trackMaskRect = CGRectMake(_maximumTrackImageView.frame.origin.x, _maximumTrackImageView.frame.origin.y,
                                  _maximumTrackImageView.frame.origin.x + valuePt.x + _thumbImageView.frame.size.width / 2, _maximumTrackImageView.frame.size.height);

    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.frame = trackMaskRect;
    
    CGPathRef rectPath = CGPathCreateWithRect(trackMaskRect, NULL);
    maskLayer.path = rectPath;
    CGPathRelease(rectPath);
    
    _maximumTrackImageView.layer.mask = maskLayer;
}

- (void)setEnabled:(BOOL)isEnabled
{
	[super setEnabled:isEnabled];
    
    UIControlState newState = UIControlStateNormal;
    if (!isEnabled)
        newState = UIControlStateDisabled;
	[_maximumTrackImageView setImage:[self maximumTrackImageForState:newState]];
	[_minimumTrackImageView setImage:[self minimumTrackImageForState:newState]];
	[_thumbImageView setImage:[self thumbImageForState:newState]];
}

- (BOOL)handleTouch:(UITouch *)touch {
	if (touch.tapCount > 1 && self.resetsToDefault && _canReset) {
		[self reset];
		return NO;
	}
    
    float deltaX = 0.0;
	CGPoint point = [touch locationInView:self];
    if (point.x < self.bounds.origin.x + _outOfBoundsMod * _thumbImageView.frame.size.width / 2) {
        point.x = self.bounds.origin.x + _thumbImageView.frame.size.width / 2;
    } else if (point.x > self.bounds.origin.x + self.bounds.size.width + _outOfBoundsMod * _thumbImageView.frame.size.width / 2) {
        point.x = self.bounds.origin.x + self.bounds.size.width - _thumbImageView.frame.size.width / 2;
    } else {
        _outOfBoundsMod = 0.0;
        deltaX = point.x - _lastTouchPt.x;
    }
    _lastTouchPt = point;
    
    CGRect newFrame = _thumbImageView.frame;
    newFrame.origin.x += deltaX;
    if (newFrame.origin.x < self.bounds.origin.x) {
        newFrame.origin.x = self.bounds.origin.x;
        _outOfBoundsMod = 1.0;
    } else if (newFrame.origin.x > self.bounds.origin.x + self.bounds.size.width - _thumbImageView.frame.size.width) {
        newFrame.origin.x = self.bounds.origin.x + self.bounds.size.width - _thumbImageView.frame.size.width;
        _outOfBoundsMod = -1.0;
    }
    
    [_thumbImageView setFrame:newFrame];
    self.value = [self valueForPosition:_thumbImageView.frame.origin];
    [self syncTrackToValue];
    
	return YES;
}

#pragma mark - UIControl methods

- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
	CGPoint point = [touch locationInView:self];
    _touchOrigin = point;
    _lastTouchPt = point;
    _outOfBoundsMod = 0.0;
    
    if (! CGRectContainsPoint(_thumbImageView.frame, point)) {
        point.x -= _thumbImageView.frame.size.width / 2;
        [self setValue:[self valueForPosition:point]];
        [self syncThumbToValue];
        [self syncTrackToValue];
    }
    
	self.highlighted = YES;
	_canReset = NO;
	
	return YES;
}

- (void)cancelTrackingWithEvent:(UIEvent *)event {
	self.highlighted = NO;
}

- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
	if ([self handleTouch:touch] && self.continuous) {
		[self sendActionsForControlEvents:UIControlEventValueChanged];
    }
    
	return YES;
}

- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
	self.highlighted = NO;
    
	// You can only reset the knob's position if you immediately stop dragging
	// the knob after double-tapping it, i.e. when tracking ends.
	_canReset = YES;
    
	[self handleTouch:touch];
	[self sendActionsForControlEvents:UIControlEventValueChanged];
}

@end
