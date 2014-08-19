//
//  GridLineView.m
//  RadLab
//
//  Created by Geoff Scott on 3/14/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import "GridLineView.h"

#import "UICommon.h"

static const CGFloat kInsideLineWidth = 3.0;
static const CGFloat kFrameLineWidth = 5.0;

@implementation GridLineView

// public
@synthesize initAspectRatio = _initAspectRatio;
@synthesize curAspectRatio = _curAspectRatio;
@synthesize constrainingRect = _constrainingRect;
@synthesize overlayType = _overlayType;

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _overlayType = kCropOverlayRuleOfThirds;
        _initAspectRatio = 1.0;
        _curAspectRatio = 1.0;
    }
    return self;
}

- (void)setOverlayType:(CropOverlayType) newType {
    _overlayType = newType;
    [self setNeedsDisplay];
}

- (void)setInitAspectRatio:(CGFloat)initAspectRatio {
    _initAspectRatio = initAspectRatio;
    [self setCurAspectRatio:_initAspectRatio];
}

- (void)setCurAspectRatio:(CGFloat)curAspectRatio {
    _curAspectRatio = curAspectRatio;
    [self setBounds:adjustRectToAspectRatio(self.constrainingRect, _curAspectRatio)];
    [self setNeedsDisplay];
}

- (void)resetAspectRatio {
    [self setCurAspectRatio:self.initAspectRatio];
}

- (void)drawRect:(CGRect)rect {
    if (self.bounds.size.width > 0 && self.bounds.size.height > 0) {
        switch (_overlayType) {
            case kCropOverlayGrid:
                [self drawGridWithSquares:8];
                break;
                
            case kCropOverlayRuleOfThirds:
                [self drawGridWithRows:3 andColumns:3];
                break;
                
            default:
                break;
        }
    }
}

- (void)drawGridWithSquares:(NSUInteger)numSquaresMinSide {
    if (self.bounds.size.width > self.bounds.size.height) {
        float sizeSquare = self.bounds.size.height / numSquaresMinSide;
        [self drawGridWithRows:numSquaresMinSide andColumns:self.bounds.size.width / sizeSquare];
    } else {
        float sizeSquare = self.bounds.size.width / numSquaresMinSide;
        [self drawGridWithRows:self.bounds.size.height / sizeSquare andColumns:numSquaresMinSide];
    }
}

- (void)drawGridWithRows:(NSUInteger)rowCount andColumns:(NSUInteger)columnCount {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGRect myDisplay = self.bounds;
    
    [[UIColor yellowColor] setStroke];
    CGContextSetLineWidth(context, kFrameLineWidth);
    CGRectInset(myDisplay, kFrameLineWidth, kFrameLineWidth);
    UIRectFrame(myDisplay);
    CGRectInset(myDisplay, -kFrameLineWidth, -kFrameLineWidth);
    
    CGFloat y = myDisplay.origin.y;
    for(NSUInteger i = 0; i < rowCount; i++) {
        y += myDisplay.size.height / rowCount;
        CGContextMoveToPoint(context, myDisplay.origin.x, y);
        CGContextAddLineToPoint(context, myDisplay.origin.x + myDisplay.size.width, y);
    }
    
    CGFloat x = myDisplay.origin.x;
    for(NSUInteger j = 0; j < columnCount; j++) {
        x += myDisplay.size.width / columnCount;
        CGContextMoveToPoint(context, x, myDisplay.origin.y);
        CGContextAddLineToPoint(context, x, myDisplay.origin.y + myDisplay.size.height);
    }
    
    CGContextSetLineWidth(context, kInsideLineWidth);
    CGContextStrokePath(context);
}

@end
