//
//  TapEditViewController.h
//  RadLab
//
//  Created by Geoff Scott on 7/19/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "EditGridViewCell.h"
#import "ImageDataController.h"
#import "LXReorderableCollectionViewFlowLayout.h"
#import "PTGButton.h"
#import "PTGSlider.h"
#import "ToolViewController.h"
#import <MessageUI/MessageUI.h>

typedef enum {
    kLongPressShowsOriginal,
    kLongPressShowsPrevious
} ImageLongPressBehavior;

static NSString* const kLabelHeaderID = @"labelGridHeader";
static NSString* const kRecipesHeaderID = @"recipeGridHeader";
static NSString* const kStoreBannerID = @"storeBanner";

@interface TapEditViewController : UIViewController <UICollectionViewDelegate,
                                                        UICollectionViewDataSource,
                                                        UICollectionViewDelegateFlowLayout,
                                                        LXReorderableCollectionViewDataSource,
                                                        PTGButtonDelegate,
                                                        ToolViewControllerDelegate,
                                                        UIActionSheetDelegate,
                                                        UIAlertViewDelegate,
                                                        UIGestureRecognizerDelegate,
                                                        MFMailComposeViewControllerDelegate>

@property (weak, nonatomic) ImageDataController *dataController;
@property (assign, nonatomic) NSInteger initialSectionPreference;

@property (weak, nonatomic) IBOutlet UIImageView *blurredBackground;
@property (weak, nonatomic) IBOutlet UICollectionView *gridView;
@property (weak, nonatomic) IBOutlet UIImageView *afterImageView;
@property (weak, nonatomic) IBOutlet UIImageView *beforeImageView;
@property (weak, nonatomic) IBOutlet UIImageView *folderTabsImageView;
@property (weak, nonatomic) IBOutlet UIButton *magicButton;
@property (weak, nonatomic) IBOutlet UIButton *recipeButton;
@property (weak, nonatomic) IBOutlet UIButton *libraryButton;
@property (weak, nonatomic) IBOutlet UIButton *storeButton;
@property (weak, nonatomic) IBOutlet UIView *toolBar;
@property (weak, nonatomic) IBOutlet PTGSlider *strengthSlider;
@property (weak, nonatomic) IBOutlet PTGButton *undoButton;
@property (weak, nonatomic) IBOutlet PTGButton *redoButton;
@property (weak, nonatomic) IBOutlet UIButton *toolsButton;

- (IBAction)doSliderValueChanged:(PTGSlider *)sender;
- (IBAction)doSliderStopped:(PTGSlider *)sender;
- (IBAction)doReset:(id)sender;
- (IBAction)doUndo:(id)sender;
- (IBAction)doRedo:(id)sender;
- (IBAction)doShowMagicStyletFolder:(id)sender;
- (IBAction)doShowRecipeStyletFolder:(id)sender;
- (IBAction)doShowLibraryStyletFolder:(id)sender;
- (IBAction)doShowStoreStyletFolder:(id)sender;

+ (CGSize)thumbnailSize;
+ (CGSize)previewSize;

- (BOOL)showSecondFilterNotification;
- (CGRect)calcBeforeStringFrameFrom:(CGRect)labelFrame onSide:(BOOL)bLeftSide;
- (void)displayBeforeString:(NSString *)message onSide:(BOOL)bLeftSide;
- (void)dismissBeforeString;
- (void)showOptionsForRecipeAt:(NSIndexPath *)indexPath;
- (void)showOptionsForHistoryAt:(NSIndexPath *)indexPath;
- (void)setAfterImageStrength:(float)strength;
- (void)showUnlockOptionsForStyletAt:(NSIndexPath *)indexPath;
- (void)tellDataControllerWhatIsVisible;
- (BOOL)sectionIsVisible:(NSInteger)section;
- (void)resetVisibleSections:(NSNotification*)notification;
- (void)animateUndoRedo:(BOOL)direction;
- (void)animateFromGridCell:(EditGridViewCell *)startCell;

@end