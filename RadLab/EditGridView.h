//
//  EditGridView.h
//  RadLab
//
//  Created by Geoff Scott on 11/15/12.
//  Copyright (c) 2012 Totally Rad. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "EditGridViewCell.h"

@protocol EditGridViewDataSource;
@protocol EditGridViewDelegate;

@interface EditGridView : UIView

@property (weak, nonatomic) id<EditGridViewDataSource> dataSource;
@property (weak, nonatomic) id<EditGridViewDelegate> delegate;
@property (nonatomic, copy) NSMutableArray *cellList;
@property (nonatomic, retain) UINib *cellNib;
@property (nonatomic, retain) IBOutlet EditGridViewCell *tmpCell;
@property CGRect contentFrame;

- (IBAction)handleTap:(UITapGestureRecognizer *)recognizer;

-(void)buildGrid;
-(void)reloadData;
-(EditGridViewCell *)cellForItemAtIndexPath:(NSIndexPath *)indexPath;

@end

@protocol EditGridViewDataSource <NSObject>

- (NSInteger)editGridView:(EditGridView *)view numberOfItemsInSection:(NSInteger)section;
-(void)reloadDataForCell:(EditGridViewCell *)cell withIndexPath:(NSIndexPath *)indexPath;

@end

@protocol EditGridViewDelegate <NSObject>

- (void)editGridView:(EditGridView *)view didSelectItemAtIndexPath:(NSIndexPath *)indexPath;

@end