//
//  ChooseImageCell.h
//  RadLab
//
//  Created by Geoff Scott on 11/19/12.
//  Copyright (c) 2012 Totally Rad. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ChooseImageCell : UICollectionViewCell

@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (assign) NSString *cornerRadius;

- (void)setImage:(UIImage *)image;

@end
