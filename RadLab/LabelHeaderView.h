//
//  LabelHeaderView.h
//  RadLab
//
//  Created by Geoff Scott on 1/29/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface LabelHeaderView : UICollectionReusableView

@property (weak, nonatomic) IBOutlet UILabel *textLabel;
@property (weak, nonatomic) IBOutlet UITextView *textView;

- (void)setLabel:(NSString *)text;
- (void)setHeaderText:(NSString *)text;

@end
