//
//  TestViewController.h
//  RadLab
//
//  Created by Geoff Scott on 2/25/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "AboutViewController.h"
#import "ImageDataController.h"
#import "PTGButton.h"
#import "PTGSlider.h"

@protocol EditViewPopoverDelegate <NSObject>

- (void)refresh;
- (void)dismissOpenPopover;

@end

@interface TestViewController : UIViewController <UIPopoverControllerDelegate,
                                                    AboutViewControllerDelegate,
                                                    EditViewPopoverDelegate,
                                                    PTGButtonDelegate>

@property (weak, nonatomic) ImageDataController *dataController;
@property (weak, nonatomic) IBOutlet UIButton *aboutButton;
@property (weak, nonatomic) IBOutlet UIButton *picButton;
@property (weak, nonatomic) IBOutlet UIButton *goButton;
@property (weak, nonatomic) IBOutlet UIButton *recipeButton;
@property (weak, nonatomic) IBOutlet UICollectionView *gridView;
@property (weak, nonatomic) IBOutlet UIImageView *afterImageView;
@property (weak, nonatomic) IBOutlet UIImageView *beforeImageView;
@property (weak, nonatomic) IBOutlet UIView *folderBar;
@property (weak, nonatomic) IBOutlet UIImageView *folderTabsImageView;
@property (weak, nonatomic) IBOutlet UIButton *magicFolderButton;
@property (weak, nonatomic) IBOutlet UIButton *recipeFolderButton;
@property (weak, nonatomic) IBOutlet UIButton *libraryFolderButton;
@property (weak, nonatomic) IBOutlet UIView *toolBar;
@property (weak, nonatomic) IBOutlet PTGSlider *strengthSlider;
@property (weak, nonatomic) IBOutlet PTGButton *undoButton;
@property (weak, nonatomic) IBOutlet PTGButton *redoButton;

- (IBAction)doShowAbout:(id)sender;
- (IBAction)doShowPic:(id)sender;
- (IBAction)doShowGo:(id)sender;
- (IBAction)doShowRecipe:(id)sender;
- (IBAction)doShowMagicStyletFolder:(id)sender;
- (IBAction)doShowRecipeStyletFolder:(id)sender;
- (IBAction)doShowLibraryStyletFolder:(id)sender;
- (IBAction)doReset:(id)sender;
- (IBAction)doUndo:(id)sender;
- (IBAction)doRedo:(id)sender;
- (IBAction)doSliderValueChanged:(PTGSlider *)sender;
- (IBAction)doSliderStopped:(PTGSlider *)sender;

@end

