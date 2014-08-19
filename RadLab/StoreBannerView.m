//
//  StoreBannerView.m
//  RadLab
//
//  Created by Love on 2/13/14.
//  Copyright (c) 2014 Totally Rad. All rights reserved.
//

#import "StoreBannerView.h"
#import "MKStoreManager.h"

@implementation StoreBannerView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    
    if ([MKStoreManager featurePurchased1]) {
        [self.btnBuy setBackgroundImage:[UIImage imageNamed:@"replichrome_owned"] forState:UIControlStateNormal];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    if ([MKStoreManager featurePurchased1]) {
        [self.btnBuy setBackgroundImage:[UIImage imageNamed:@"replichrome_owned"] forState:UIControlStateNormal];
    }
}

@end
