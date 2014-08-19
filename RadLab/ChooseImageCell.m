//
//  ChooseImageCell.m
//  RadLab
//
//  Created by Geoff Scott on 11/19/12.
//  Copyright (c) 2012 Totally Rad. All rights reserved.
//

#import "ChooseImageCell.h"
#import <QuartzCore/QuartzCore.h>

@implementation ChooseImageCell

@synthesize imageView = _imageView;
@synthesize cornerRadius = _cornerRadius;

/*
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}
*/

/*
- (void)awakeFromNib {
    if ([self.cornerRadius floatValue] != 0.0) {
        self.imageView.layer.cornerRadius = [self.cornerRadius floatValue];
        self.imageView.layer.masksToBounds = YES;

        self.contentView.layer.masksToBounds = YES;
        self.contentView.layer.cornerRadius = [self.cornerRadius floatValue];
    }
}
*/

- (void)setImage:(UIImage *)image {
    [self.imageView setImage:image];
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
