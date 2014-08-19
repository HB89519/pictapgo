//
//  PTGToolBar.m
//  RadLab
//
//  Created by Geoff Scott on 1/9/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import "PTGToolBar.h"
#import <QuartzCore/QuartzCore.h>

@implementation PTGToolBar

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    [super drawRect:rect];
    
    // Drawing code

    CGMutablePathRef smileyPath = CGPathCreateMutable();
    CGPathMoveToPoint(smileyPath, NULL, self.bounds.origin.x + 1.0, self.bounds.origin.y - 1.0);
    CGPathAddLineToPoint(smileyPath, NULL, self.bounds.origin.x + 1.0, self.bounds.origin.y + self.bounds.size.height - 1.0);
    CGPathAddLineToPoint(smileyPath, NULL, self.bounds.origin.x + self.bounds.size.width - 1.0, self.bounds.origin.y + self.bounds.size.height - 1.0);
    CGPathAddLineToPoint(smileyPath, NULL, self.bounds.origin.x + self.bounds.size.width - 1.0, self.bounds.origin.y - 1.0);
    CGFloat cp1x = self.bounds.origin.x + self.bounds.size.width * 2 / 3;
    CGFloat cp2x = self.bounds.origin.x + self.bounds.size.width / 3;
    CGFloat cpy = self.bounds.origin.y + self.bounds.size.height / 4;
    CGPathAddCurveToPoint(smileyPath, NULL, cp1x, cpy, cp2x, cpy, self.bounds.origin.x, self.bounds.origin.y);

    if (smileyPath) {
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextAddPath(context, smileyPath);
        CGContextSetRGBStrokeColor(context, 0, 0, 1.0, 0.5);
        CGContextSetLineJoin(context, kCGLineJoinRound);
        CGContextSetLineCap(context, kCGLineCapRound);
        CGContextSetLineWidth(context, 1.0);
        CGContextStrokePath(context);
        CGPathRelease(smileyPath);
    }
}
*/

@end
