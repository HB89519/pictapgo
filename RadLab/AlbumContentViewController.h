//
//  AlbumContentViewController.h
//  RadLab
//
//  Created by Geoff Scott on 12/7/12.
//  Copyright (c) 2012 Totally Rad. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "ImageDataController.h"
#import "WorkspaceViewController.h"

@interface AlbumContentViewController : UIViewController <UICollectionViewDelegate>

@property (weak, nonatomic) id<WorkspaceViewPopoverDelegate> popoverDelegate;
@property (weak, nonatomic) ImageDataController *dataController;
@property (weak, nonatomic) IBOutlet UICollectionView *gridView;
@property (weak, nonatomic) IBOutlet UIButton *editButton;
@property (weak, nonatomic) IBOutlet UIImageView *navImageBack;

- (void) setAssetsGroup:(ALAssetsGroup*)group;

- (IBAction)doBack:(id)sender;

@end
