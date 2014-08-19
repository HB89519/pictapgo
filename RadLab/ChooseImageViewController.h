//
//  ChooseImageViewController.h
//  RadLab
//
//  Created by Geoff Scott on 10/29/12.
//  Copyright (c) 2012 Totally Rad. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AboutViewController.h"
#import "CameraOverlayViewController.h"
#import "ImageDataController.h"
#import "WorkspaceViewController.h"

@interface ChooseImageViewController : UIViewController <CameraOverlayViewControllerDelegate,
                                                        AboutViewControllerDelegate,
                                                        UICollectionViewDelegateFlowLayout,
                                                        UICollectionViewDelegate>

@property (weak, nonatomic) ImageDataController *dataController;
@property (weak, nonatomic) id<WorkspaceViewPopoverDelegate> popoverDelegate;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UICollectionView *gridView;
@property (weak, nonatomic) IBOutlet UIButton *editButton;
@property (weak, nonatomic) IBOutlet UIButton *pasteButton;
@property (weak, nonatomic) IBOutlet UIButton *albumsButton;
@property (weak, nonatomic) IBOutlet UIView *toolBar;
@property (weak, nonatomic) IBOutlet UIImageView *navImageBack;
@property (weak, nonatomic) IBOutlet UIImageView *toolImageBack;

- (IBAction)showCamera:(id)sender;
- (IBAction)pasteImage:(id)sender;
- (IBAction)chooseAlbums:(id)sender;
- (IBAction)doBack:(id)sender;  // DEBUG method, not for production deployment

@end
