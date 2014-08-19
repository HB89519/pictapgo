//
//  EditGridViewCell.h
//  RadLab
//
//  Created by Geoff Scott on 10/31/12.
//  Copyright (c) 2012 Totally Rad. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface EditGridViewCell : UICollectionViewCell

@property (weak, nonatomic) IBOutlet UIButton *btnAddFilter;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UIImageView *cellBackground;
@property (weak, nonatomic) IBOutlet UILabel *styletLabel;
@property (assign) NSString *cornerRadius;
@property (assign, nonatomic) NSInteger cellType;

- (void)setImage:(UIImage *)image;
- (void)setStyletName:(NSString *)name;

@end
