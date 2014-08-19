//
//  ChooseImageFooter.m
//  RadLab
//
//  Created by Geoff Scott on 11/29/12.
//  Copyright (c) 2012 Totally Rad. All rights reserved.
//

#import "ChooseImageFooter.h"

@implementation ChooseImageFooter

@synthesize imageCountLabel = _imageCountLabel;

- (id)init {
    self = [super init];
    return self;
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    return [super initWithCoder:aDecoder];
}

- (void)dealloc {

}

- (void)prepareForReuse {
    [super prepareForReuse];
}

- (void)willTransitionFromLayout:(UICollectionViewLayout *)oldLayout toLayout:(UICollectionViewLayout *)newLayout {
    [super willTransitionFromLayout:oldLayout toLayout:newLayout];
}

- (void)didTransitionFromLayout:(UICollectionViewLayout *)oldLayout toLayout:(UICollectionViewLayout *)newLayout {
    [super didTransitionFromLayout:oldLayout toLayout:newLayout];
}

- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes {
    [super applyLayoutAttributes:layoutAttributes];
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
