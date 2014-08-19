//
//  StyletViewController.h
//  RadLab
//
//  Created by Geoff Scott on 2/27/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "ImageDataController.h"
#import "ImageViewController.h"

@protocol EditViewPopoverDelegate <NSObject>

- (void)refresh;
- (void)dismissOpenPopover;

@optional
    // for a viewcontroller, these already exist, but the client(?) needs to know about them explicitly
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion;
- (void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion;
@end

@interface StyletViewController : UIViewController <UICollectionViewDelegate,
                                                    UICollectionViewDataSource,
                                                    UICollectionViewDelegateFlowLayout,
                                                    UIPopoverControllerDelegate,
                                                    EditViewPopoverDelegate>

@property (weak, nonatomic) ImageDataController *dataController;
@property (weak, nonatomic) ImageViewController *imageController;
@property (assign, nonatomic) NSInteger sectionID;

@property (weak, nonatomic) IBOutlet UICollectionView *gridView;
@property (weak, nonatomic) IBOutlet UIImageView *folderTabsImageView;
@property (weak, nonatomic) IBOutlet UIButton *picButton;
@property (weak, nonatomic) IBOutlet UIButton *aboutButton;
@property (weak, nonatomic) IBOutlet UIButton *magicButton;
@property (weak, nonatomic) IBOutlet UIButton *recipeButton;
@property (weak, nonatomic) IBOutlet UIButton *libraryButton;

- (IBAction)doShowPic:(id)sender;
- (IBAction)doShowAbout:(id)sender;
- (IBAction)doShowMagicStyletFolder:(id)sender;
- (IBAction)doShowRecipeStyletFolder:(id)sender;
- (IBAction)doShowLibraryStyletFolder:(id)sender;

@end
