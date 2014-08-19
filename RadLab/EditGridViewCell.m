//
//  EditGridViewCell.m
//  RadLab
//
//  Created by Geoff Scott on 10/31/12.
//  Copyright (c) 2012 Totally Rad. All rights reserved.
//

#import "EditGridViewCell.h"
#import "ImageDataController.h"
#import <QuartzCore/QuartzCore.h>

@implementation EditGridViewCell

@synthesize imageView = _imageView;
@synthesize cellBackground = _cellBackground;
@synthesize styletLabel = _styletLabel;
@synthesize cornerRadius = _cornerRadius;
@synthesize cellType = _cellType;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

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

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

- (void)setImage:(UIImage *)image {
    if (image)
        [self.imageView setImage:image];
    else {
        static UIImage* spinner = nil;
        if (!spinner)
            spinner = [UIImage animatedImageNamed:@"loading-" duration:1.0];
        [self.imageView setImage:spinner];
    }
}

- (void)setStyletName:(NSString *)name {
    [self.styletLabel setText:name];
}

- (void)setCellType:(NSInteger)cellType {
    if (cellType != _cellType) {
        _cellType = cellType;
    
        switch (cellType) {
            case kStyletCellType:
                [self.cellBackground setImage:[UIImage imageNamed:@"Background_StyletCell"]];
                break;
            case kRecipeCellType:
                [self.cellBackground setImage:[UIImage imageNamed:@"Background_RecipeCell"]];
                break;
            case kLockedMailingListCellType:
                [self.cellBackground setImage:[UIImage imageNamed:@"Background_MailingListCell"]];
                break;
            case kLockedFacebookCellType:
                [self.cellBackground setImage:[UIImage imageNamed:@"Background_FacebookCell"]];
                break;
            case kLockedInstagramCellType:
                [self.cellBackground setImage:[UIImage imageNamed:@"Background_InstagramCell"]];
                break;
            case kLockedTwitterCellType:
                [self.cellBackground setImage:[UIImage imageNamed:@"Background_TwitterCell"]];
                break;
            default:
                [self.cellBackground setImage:[UIImage imageNamed:@"Background_StyletCell"]];
                break;
        }
    }
}

@end
