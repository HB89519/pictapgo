//
//  EditGridHeaderView.h
//  RadLab
//
//  Created by Geoff Scott on 11/19/12.
//  Copyright (c) 2012 Totally Rad. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PTGPageControl.h"

@interface EditGridHeaderView : UICollectionReusableView

@property (weak, nonatomic) IBOutlet UIImageView *afterImageView;
@property (weak, nonatomic) IBOutlet UIImageView *beforeImageView;
@property (weak, nonatomic) IBOutlet UISlider *strengthSlider;
@property (weak, nonatomic) IBOutlet PTGPageControl *filterPageDisplay;
@property (weak, nonatomic) IBOutlet UIButton *helpButton;
@property (weak, nonatomic) IBOutlet UIButton *toolsButton;

@end
