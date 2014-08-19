//
//  EditGridHeaderView.m
//  RadLab
//
//  Created by Geoff Scott on 11/19/12.
//  Copyright (c) 2012 Totally Rad. All rights reserved.
//

#import "EditGridHeaderView.h"
#import <QuartzCore/QuartzCore.h>

static int ddLogLevel = LOG_LEVEL_INFO;

@implementation EditGridHeaderView

@synthesize afterImageView = _afterImageView;
@synthesize beforeImageView = _beforeImageView;
@synthesize strengthSlider = _strengthSlider;
@synthesize filterPageDisplay = _filterPageDisplay;
@synthesize helpButton = _helpButton;
@synthesize toolsButton = _toolsButton;

static int count;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    ++count;
    DDLogInfo(@"EditGridHeaderView initWithFrame %p count %d", self, count);
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    ++count;
    DDLogInfo(@"EditGridHeaderView initWithCoder %p count %d", self, count);
    return self;
}

- (void)dealloc {
    --count;
    DDLogInfo(@"EditGridHeaderView dealloc %p (count %d)", self, count);
}

/*
- (void)prepareForReuse {
    DDLogInfo(@"EditGridViewController prepare for reuse %p", self);
    [super prepareForReuse];
}
*/

/*
- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes {
    DDLogVerbose(@"EditGridViewController apply layout %p %p", self, layoutAttributes);
    [super applyLayoutAttributes:layoutAttributes];
}
*/

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
