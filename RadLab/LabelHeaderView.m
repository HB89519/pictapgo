//
//  LabelHeaderView.m
//  RadLab
//
//  Created by Geoff Scott on 1/29/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import "LabelHeaderView.h"

@implementation LabelHeaderView

@synthesize textLabel = _textLabel;
@synthesize textView = _textView;

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
    // Drawing code
}
*/

- (void)setLabel:(NSString *)text {
    [self.textLabel setText:text];
}

- (void)setHeaderText:(NSString *)text {
    [self.textView setText:text];
}

@end
