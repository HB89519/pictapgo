//
//  PTGPageControl.h
//  RadLab
//
//  Created by Geoff Scott on 2/8/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PTGPageControl : UIControl

@property (nonatomic, assign) NSUInteger numberOfPages;
@property (nonatomic, assign) NSUInteger currentPage;

- (void)resetPageCount;
- (void)setImage:(UIImage *)image forPage:(NSUInteger)pageNumber;

@end
