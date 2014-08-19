//
//  EditGridViewController.m
//  RadLab
//
//  Created by Geoff Scott on 10/29/12.
//  Copyright (c) 2012 Totally Rad. All rights reserved.
//

#import "EditGridViewController.h"

#import "MBProgressHUD.h"

#import "AppSettings.h"
#import "EditGridHeaderView.h"
#import "EditGridViewCell.h"
#import "LabelHeaderView.h"
#import "StoreBannerView.h"
#import "MemoryStatistics.h"
#import <MobileCoreServices/UTCoreTypes.h>
#import "PTGNotify.h"
#import <QuartzCore/QuartzCore.h>
#import "ShareViewController.h"
#import "Scaling.h"
#import "ToolViewController.h"
#import "TRStatistics.h"
#import "UICommon.h"
#import "UIDevice-Hardware.h"
#import <libkern/OSAtomic.h>

static int ddLogLevel = LOG_LEVEL_INFO;

// *** additional interface ***

@interface EditGridViewController () <UIScrollViewDelegate, UIActionSheetDelegate>
{
    CGPoint _previousContentOffset;
    CGRect _initialPreviewFrame;
    CGRect _saveFolderBarFrame;
    CGFloat _previewHeightAdjustment;
    BOOL _hasRetinaDisplay;
    BOOL _animating;
    BOOL _visibleThumbnailsChanged;
    BOOL _showingOriginal;
}

@property (nonatomic, retain) UIView *notificationView;

@end

// *** constants ***

static NSString *kFilterHeaderID = @"filterGridHeader";
static NSString *idleInEditView = @"idleInEditView";

static const CGFloat kDepthOfSmileyCurve = 15.0;
static const CGFloat kPreviewOfCellHeightNoBar = 30.0;
static const CGFloat kPreviewOfCellHeight = 60.0;

static const CGFloat kHeightRecipesHeader = 100.0;
static const CGFloat kHeightHistoryHeader = 24.0;
static const CGFloat kHeightStoreBanner = 130.0;

// *** implementation ***
@implementation EditGridViewController

// public
@synthesize folderBar = _folderBar;
@synthesize helpButton = _helpButton;

// private
@synthesize notificationView = _notificationView;

- (void)dealloc {
    DDLogInfo(@"EditGridViewController dealloc (mem %@)", stringWithMemoryInfo());
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.dataController releaseMemoryForEditView];
    if (self.isViewLoaded)
        [self.view.layer removeAllAnimations];
    DDLogInfo(@"finish EditGridViewController dealloc (mem %@)", stringWithMemoryInfo());
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _hasRetinaDisplay = deviceHasRetinaDisplay();
    _previousContentOffset = CGPointMake(0.0, 0.0);
    _animating = NO;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(idle:) name:idleInEditView object:nil];
    
    [self updateHeaderAdjustment];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if (! AppSettings.manager.useSimpleBackground) {
        [self.blurredBackground setImage:blurImage([self.dataController masterPreview])];
    } else {
        [self.blurredBackground setImage:nil];
    }

    [self.dataController editViewWillAppear];
    [self.dataController rebuildCurrentThumbnails];

    _visibleThumbnailsChanged = YES;
    
    // refresh thumbs and header (when returning from Tools, etc)
    [self.gridView reloadData];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [PTGNotify reset];
    if (! AppSettings.manager.visitedTapScreen)
        [PTGNotify displayInitialHelp:@"Help_Tap" withAlertTitle:NSLocalizedString(@"STYLE IT", nil) pageNumber:2 ofTotalPageCount:4 withButtonTitle:NSLocalizedString(@"Start Tapping!", nil) aboveViewController:self];

    [self.folderBar setHidden:[self.dataController hasFiltersApplied]];
    addMaskToToolBar(self.toolBar);
    [self updateHeaderAdjustment];
    [self scrollSyncFolderBar];
    
    if (! AppSettings.manager.useSimpleBackground) {
        [self.blurredBackground setImage:blurImage([self.dataController masterPreview])];
    } else {
        [self.blurredBackground setImage:nil];
    }
    
    if (_initialPreviewFrame.size.width == 0.0
      && _initialPreviewFrame.size.height == 0.0) {
        _initialPreviewFrame = self.beforeImageView.frame;
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [self.dataController editViewWillDisappear];
    [self.dataController releaseMemoryForEditView];
    AppSettings.manager.editViewInitialFolder = self.initialSectionPreference;
    AppSettings.manager.visitedTapScreen = YES;
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    DDLogError(@"**** edit view DidDisappear ***");
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self scrollSyncFolderBar];
    [self scrollSyncToolBar];
}

- (void)idle:(NSNotification*)ignored {
    DDLogVerbose(@"idle in Edit View");
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    DDLogInfo(@"*** prepareForSegue begin %@", [segue identifier]);
    if ([[segue identifier] isEqualToString:@"showShare"]) {
        [self.dataController pruneRedoState];
        [self.dataController updateMagicWeights];
        ShareViewController *shareController = (ShareViewController *)[segue destinationViewController];
        [shareController setDataController:self.dataController];
    } else if ([[segue identifier] isEqualToString:@"showHelp"]) {
        AboutViewController *aboutController = (AboutViewController *)[segue destinationViewController];
        aboutController.navigation = [sender isKindOfClass:[AboutViewNavigation class]] ? sender : nil;
        [aboutController setDelegate:self];
        [aboutController setDataController:self.dataController];
    }
    [super prepareForSegue:segue sender:sender];
    DDLogInfo(@"*** prepareForSegue end %@", [segue identifier]);
}

- (IBAction)doBack:(id)sender {
    @autoreleasepool {
        UINavigationController *navCon = [self navigationController];
        [navCon popViewControllerAnimated:YES];
    }
}

- (IBAction)doShowHelp:(id)sender {
    [self performSegueWithIdentifier:@"showHelp" sender:[AboutViewNavigation newHelpURL:@"basics.html#tap_screen"]];
}

- (IBAction)doReset:(id)sender {
    if ([self.dataController currentStepIndex] != 0) {
        [super doReset:sender];
        [self updateHeaderAdjustment];
    }
}

- (IBAction)handleSwipeFrom:(UISwipeGestureRecognizer *)recognizer {
    if (recognizer.direction == UISwipeGestureRecognizerDirectionLeft) {
        [self doRedo:self];
    } else {
        [self doUndo:self];
    }
}

- (IBAction)handleTap:(UITapGestureRecognizer *)recognizer {
    if ([PTGNotify isMessageCurrentlyDisplayed])
        return;
    
    BOOL bInsideMagicButton = NO;
    BOOL bInsideRecipeButton = NO;
    BOOL bInsideLibraryButton = NO;
    BOOL bInsideStoreButton = NO;
    
    NSUInteger numTouches = [recognizer numberOfTouches];
    for (NSUInteger i = 0; i < numTouches; ++i ) {
        CGPoint location = [recognizer locationOfTouch:i inView:self.toolBar];
        // compare using bounds for toolBar because its frame is relative to its parent view
        // compare using frame for the buttons because their frames are relative to the folderBar
        if (CGRectContainsPoint(self.toolBar.bounds, location)) {
            break;
        } else {
            location = [recognizer locationOfTouch:i inView:self.folderBar];
            if (CGRectContainsPoint(self.magicButton.frame, location)) {
                bInsideMagicButton = YES;
                break;
            } else if (CGRectContainsPoint(self.recipeButton.frame, location)) {
                bInsideRecipeButton = YES;
                break;
            } else if (CGRectContainsPoint(self.libraryButton.frame, location)) {
                bInsideLibraryButton = YES;
                break;
            }
            else if (CGRectContainsPoint(self.storeButton.frame, location)) {
                bInsideStoreButton = YES;
                break;
            }
        }
    }
    
    if ([recognizer state] == UIGestureRecognizerStateEnded) {
        if (bInsideRecipeButton && [self.recipeButton isEnabled]) {
            [self.recipeButton sendActionsForControlEvents:UIControlEventTouchUpInside];
        } else if (bInsideLibraryButton && [self.libraryButton isEnabled]) {
            [self.libraryButton sendActionsForControlEvents:UIControlEventTouchUpInside];
        } else if (bInsideMagicButton && [self.magicButton isEnabled]) {
            [self.magicButton sendActionsForControlEvents:UIControlEventTouchUpInside];
        } else if (bInsideStoreButton && [self.storeButton isEnabled]) {
            [self.storeButton sendActionsForControlEvents:UIControlEventTouchUpInside];
        }
    }
}

- (CGRect)calcBeforeStringFrameFrom:(CGRect)labelFrame onSide:(BOOL)bLeftSide {
    CGRect screenFrame = self.view.frame;
    CGRect retFrame = labelFrame;
    
    if (bLeftSide) {
        retFrame.origin.x = screenFrame.origin.x + 8.0;
    } else {
        retFrame.origin.x = screenFrame.origin.x +screenFrame.size.width - 8 - retFrame.size.width;
    }
    retFrame.origin.y = screenFrame.origin.y + 48.0 - self.gridView.contentOffset.y;
    if (retFrame.origin.y < screenFrame.origin.y) {
        retFrame.origin.y = screenFrame.origin.y;
    }
    
    return retFrame;
}

- (IBAction)handleShortPress:(UILongPressGestureRecognizer *)recognizer {
    if ([PTGNotify isMessageCurrentlyDisplayed])
        return;
    
    BOOL bInsideImageView = NO;
    NSInteger behaviorPref;
    
    CGRect previewFrame = self.afterImageView.frame;
    CGRect leftFrame = previewFrame;
    leftFrame.size.width = previewFrame.size.width / 2;
    CGRect rightFrame = previewFrame;
    rightFrame.size.width = leftFrame.size.width;
    rightFrame.origin.x += rightFrame.size.width;
    
    NSUInteger numTouches = [recognizer numberOfTouches];
    for (NSUInteger i = 0; i < numTouches; ++i ) {
		CGPoint location = [recognizer locationOfTouch:i inView:self.gridView];
        if (CGRectContainsPoint(leftFrame, location)) {
            bInsideImageView = YES;
            behaviorPref = kLongPressShowsOriginal;
            break;
        } else if (CGRectContainsPoint(rightFrame, location)) {
            bInsideImageView = YES;
            behaviorPref = kLongPressShowsPrevious;
            break;
        }
    }
    
    if ([recognizer state] == UIGestureRecognizerStateBegan) {
        if (bInsideImageView) {
            NSString *displayStr = nil;
            if ((numTouches > 1 && behaviorPref == kLongPressShowsPrevious)
              || (numTouches == 1 && behaviorPref == kLongPressShowsOriginal)) {
                _showingOriginal = YES;
                [self.beforeImageView setImage:[self.dataController masterPreview]];
                displayStr = NSLocalizedString(@"Original", nil);
            } else {
                _showingOriginal = NO;
                displayStr = NSLocalizedString(@"Previous", nil);
            }
            [self.afterImageView setHidden:YES];
            [self displayBeforeString:displayStr onSide:behaviorPref == kLongPressShowsOriginal];
        }
    } else if ([recognizer state] == UIGestureRecognizerStateEnded) {
        [self.afterImageView setHidden:NO];
        _showingOriginal = NO;
        [self.beforeImageView setImage:[self.dataController previousPreview]];
        [self dismissBeforeString];
    }
}

- (IBAction)handleLongPress:(UILongPressGestureRecognizer *)recognizer {
    if ([PTGNotify isMessageCurrentlyDisplayed])
        return;
    
    // handle case that press is actually on the folderBar, when cell below it on screen
    CGPoint ptInFolderBar = [recognizer locationInView:self.folderBar];
    if (CGRectContainsPoint(self.folderBar.bounds, ptInFolderBar))
        return;
    
    CGPoint ptInGrid = [recognizer locationInView:self.gridView];
    NSIndexPath *selectedIndexPath = [self.gridView indexPathForItemAtPoint:ptInGrid];

    if ([recognizer state] == UIGestureRecognizerStateBegan) {
        if (selectedIndexPath) {
            switch (selectedIndexPath.section) {
                case kStyletFolderIDRecipes:
                    [self showOptionsForRecipeAt:selectedIndexPath];
                    break;
                    
                case kStyletFolderIDHistory:
                    [self showOptionsForHistoryAt:selectedIndexPath];
                    break;
                    
                default:
                    break;
            }
        }
    }
}

- (void)animateUndoRedo:(BOOL)direction {
    _animating = YES;
    _saveFolderBarFrame = self.folderBar.frame;
    
    NSInteger dirMod = 1;
    if (!direction)
        dirMod = -1;
    
    CGRect origImageFrame = self.afterImageView.frame;
    float width = origImageFrame.size.width;
    float height = origImageFrame.size.height;
    
    UIImageView *movingImageView = [[UIImageView alloc] initWithFrame:CGRectMake(-width * dirMod, origImageFrame.origin.y, width, height)];
    [movingImageView setContentMode:UIViewContentModeScaleAspectFit];
    [movingImageView setImage:[self.dataController currentPreviewAtFullStrength]];
    setPreviewStylingForView(movingImageView);
    [self.view addSubview:movingImageView];
    
    // animate it all
    float duration = 0.25f;
    if ([[UIDevice currentDevice] platformType] == UIDevice4iPhone)
        duration = 0.4f;
    [UIView animateWithDuration:duration
                          delay:0.0f
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         [movingImageView setFrame:origImageFrame];
                     }
                     completion:^(BOOL finished){
                         if (finished) {
                             [self.afterImageView setImage:[self.dataController currentPreviewAtFullStrength]];
                             [movingImageView removeFromSuperview];
                             _animating = NO;
                         }
                     }];
}

- (void)animateFromGridCell:(EditGridViewCell *)startCell {
    _animating = YES;
    
    // setup for moving the chosen grid cell
    UIImageView *newImageView = nil;
    UIImageView *startImageView = nil;
    CGRect currImageRect;
    if (startCell) {
        startImageView = startCell.imageView;
        float cellWidth = startImageView.frame.size.width;
        float cellHeight = startImageView.frame.size.height;
        currImageRect = CGRectMake(startCell.frame.origin.x + startCell.superview.frame.origin.x - self.gridView.contentOffset.x,
                                          startCell.frame.origin.y+ startCell.superview.frame.origin.y - self.gridView.contentOffset.y,
                                          cellWidth, cellHeight);
    } else {
        startImageView = self.beforeImageView;
        currImageRect = startImageView.frame;
    }
    
    newImageView = [[UIImageView alloc] initWithImage:startImageView.image];
    [newImageView setContentMode:UIViewContentModeScaleAspectFill];
    
    // must use the cell's frame, because the cell's imageView is relative coords
    [newImageView setFrame:currImageRect];
    [newImageView setClipsToBounds:YES];
    [self.view addSubview:newImageView];

    CGSize screen = self.view.frame.size;
    CGSize bigFrameSize = scaleAspectFill(self.afterImageView.image.size, screen, false);
    CGPoint bigFrameOrigin = CGPointMake((screen.width - bigFrameSize.width) / 2.0,
      (screen.height - bigFrameSize.height) / 2.0);
    CGRect bigFrame;
    bigFrame.origin = bigFrameOrigin;
    bigFrame.size = bigFrameSize;
    
    // animate it all
    [self.toolBar setHidden:(startCell != nil)];
    [UIView animateWithDuration:0.5f
                          delay:0.0f
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         [newImageView setFrame:bigFrame];
                     }
                     completion:^(BOOL finished){

                         if (finished) {
                             [self.gridView setContentOffset:CGPointZero];
                             [self.gridView reloadData];
                             
                             UIImage* image = [self.dataController currentPreviewAtFullStrength];
                             [self.afterImageView setImage:image];
                             [self setAfterImageStrength:1.0];
                             CGSize imageSize = image.size;
                             CGRect tempFrame;
                             if (self.view.frame.size.height > self.view.frame.size.width) {
                                 if (imageSize.width >= imageSize.height) {
                                     tempFrame.size.width = imageSize.width * self.view.frame.size.height / imageSize.height;
                                     tempFrame.size.height = self.view.frame.size.height;
                                     tempFrame.origin.x = newImageView.frame.origin.x - (tempFrame.size.width - newImageView.frame.size.width) / 2.0;
                                     tempFrame.origin.y = 0.0;
                                 } else {
                                     tempFrame.size.width = newImageView.frame.size.width;
                                     tempFrame.size.height = imageSize.height * newImageView.frame.size.width / imageSize.width;
                                     tempFrame.origin.y = newImageView.frame.origin.y - (tempFrame.size.height - newImageView.frame.size.height) / 2.0;;
                                     tempFrame.origin.x = newImageView.frame.origin.x - (tempFrame.size.width - newImageView.frame.size.width) / 2.0;
                                 }
                             } else {
                                 if (imageSize.height >= imageSize.width) {
                                     tempFrame.size.height = imageSize.height * self.view.frame.size.width / imageSize.width;
                                     tempFrame.size.width = self.view.frame.size.width;
                                     tempFrame.origin.y = newImageView.frame.origin.y - (tempFrame.size.height - newImageView.frame.size.height) / 2.0;;
                                     tempFrame.origin.x = 0.0;
                                 } else {
                                     tempFrame.size.height = newImageView.frame.size.height;
                                     tempFrame.size.width = imageSize.width * newImageView.frame.size.height / imageSize.height;
                                     tempFrame.origin.x = newImageView.frame.origin.x - (tempFrame.size.width - newImageView.frame.size.width) / 2.0;;
                                     tempFrame.origin.y = newImageView.frame.origin.y - (tempFrame.size.height - newImageView.frame.size.height) / 2.0;
                                 }
                             }
                             CGRect newFrame = [self calculateDestRect];
                             [newImageView setFrame:tempFrame];
                             [newImageView setContentMode:UIViewContentModeScaleAspectFit];
                             [newImageView setImage:image];
                             [self.folderBar setHidden:YES];
                             [UIView animateWithDuration:0.25f
                                                   delay:0.15f
                                                 options:UIViewAnimationOptionCurveEaseInOut
                                              animations:^{
                                                  [newImageView setFrame:newFrame];
                                                  [self.toolBar setHidden:[self.dataController appliedStepsCount] == 1];
                                             }
                                              completion:^(BOOL finished){
                                                  if (finished) {
                                                      [newImageView removeFromSuperview];
                                                      [self.gridView setUserInteractionEnabled:YES];
                                                      _animating = NO;
                                                      [self scrollSyncFolderBar];
                                                      [self.folderBar setHidden:NO];
                                                      [self showSecondFilterNotification];
                                                  }
                                              }];
                         }
                    }
     ];
}

- (BOOL)showSecondFilterNotification {
    BOOL retval = [super showSecondFilterNotification];
    if (!retval  && ! AppSettings.manager.appliedTwoFilters) {
        NSArray *nibContents = [[NSBundle mainBundle] loadNibNamed:@"Notify_SecondFilter" owner:self options:nil];
        self.notificationView = [nibContents objectAtIndex:0];
        [self.view addSubview:self.notificationView];
        [self.notificationView setFrame:CGRectMake(320.0, 0.0, 320, 48)];
        [UIView animateWithDuration:0.25 animations:^{
            [self.notificationView setFrame:CGRectMake(0.0, 0.0, 320, 48)];            
        }];
        retval = YES;
    }
    return retval;
}

- (IBAction)doDismissNotification:(id)sender {
    if (self.notificationView) {
        [self.notificationView removeFromSuperview];
        self.notificationView = nil;
    }
}

- (CGRect)calculateDestRect {
    CGRect newFrame = _initialPreviewFrame;
    CGFloat adjustment = 0.0;
    if ([self.dataController appliedStepsCount] > 1) {
        adjustment = kPreviewOfCellHeight;
    }
    newFrame.size.height += adjustment;

    return newFrame;
}

- (void)scrollSyncNotification {
    if (self.notificationView) {
        float y_offset = self.gridView.contentOffset.y;
        float y_cur = self.notificationView.frame.origin.y;
        CGRect newFrame = self.notificationView.frame;
        newFrame.origin.y = - y_offset;
    
        if (y_offset > self.notificationView.frame.size.height) {
            [self doDismissNotification:self];
        } else if (newFrame.origin.y != y_cur) {
            [self.notificationView setFrame:newFrame];
        }
    }
}

- (void)scrollSyncToolBar {
    float y_offset = self.gridView.contentOffset.y;
    float y_cur = self.toolBar.frame.origin.y;
    CGRect newFrame = self.toolBar.frame;
    newFrame.origin.y = self.view.frame.size.height;
    
    if (y_offset <= self.toolBar.frame.size.height) {
        newFrame.origin.y += MAX(0, y_offset) - self.toolBar.frame.size.height;
    }
    
    if (newFrame.origin.y != y_cur) {
        [self.toolBar setFrame:newFrame];
    }
}

- (void)scrollSyncFolderBar {
    if (! _animating) {
        // calc place at bottom of the screen. It changes if anything applied to photo.
        float maxY = self.gridView.frame.size.height - self.folderBar.frame.size.height - _previewHeightAdjustment;
        
        // check that initial sizes & layouts have happened, so folderBar doesn't jump initially
        if (maxY > 0) {
            float y_offset = self.gridView.contentOffset.y;
            float y_delta = y_offset - _previousContentOffset.y;
            float y_cur = self.folderBar.frame.origin.y;
            
            if (y_offset > 10) {
                [self.folderBar setHidden:NO];
            } else if (!self.toolBar.isHidden) {
                [self.folderBar setHidden:YES];
            }
            
            CGRect newFrame = self.folderBar.frame;
            newFrame.origin.y -= y_delta;
    
            if (newFrame.origin.y < 0) {
                // never let the bar go off the top of the screen
                newFrame.origin.y = 0;
            } else if (newFrame.origin.y > maxY) {
                // never let the bar go off the bottom of the screen
                newFrame.origin.y = maxY;
            } else if (y_offset > maxY) {
                // don't move the bar from top until it's original location starts coming back down
                newFrame.origin.y = 0;
            } else if (y_offset < 0) {
                // don't move on bounces off the bottom
                newFrame.origin.y = maxY;
            }
    
            float masterPosition = maxY;
            newFrame.origin.y = masterPosition - y_offset;
            if (newFrame.origin.y < 0)
                newFrame.origin.y = 0;

            if (newFrame.origin.y != y_cur)
                [self.folderBar setFrame:newFrame];
        }
    } else {
        [self.folderBar setFrame:_saveFolderBarFrame];
    }
}

- (void)updateHeaderAdjustment {
    _previewHeightAdjustment = kPreviewOfCellHeight;
    if ([self.dataController appliedStepsCount] > 1) {
        _previewHeightAdjustment = 0.0;
    }
}

- (void)refreshDataDisplay:(NSNotification*)notification {
    [self.gridView reloadData];
}

#pragma mark - UICollectionViewDataSource

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    UICollectionReusableView *retHeader = nil;

    DDLogVerbose(@"Edit supplementary %@ at %@", kind, indexPath);
    if (indexPath.section == 0) {
        EditGridHeaderView *header = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:kFilterHeaderID forIndexPath:indexPath];
        if (! _animating) {
            if (_showingOriginal) {
                [header.beforeImageView setImage:[self.dataController masterPreview]];
            } else {
                [header.beforeImageView setImage:[self.dataController previousPreview]];
            }
            [header.afterImageView setImage:[self.dataController currentPreviewAtFullStrength]];
            float strength = 1.0;
            if ([self.dataController currentStepIndex] != 0) {
                strength = [[self.dataController currentStrength] floatValue] / 100.0;
            }
            [header.afterImageView setAlpha:strength];
            [self setAfterImageStrength:strength];
        }

        self.helpButton = header.helpButton;
        self.toolsButton = header.toolsButton;
        
        [self setBeforeImageView:header.beforeImageView];
        setPreviewStylingForView(self.beforeImageView);

        [self setAfterImageView:header.afterImageView];
        retHeader = header;
    } else if (indexPath.section == kStyletFolderIDHistory
               && ([self collectionView:collectionView numberOfItemsInSection:indexPath.section] > 0)) {
        LabelHeaderView *labelHeader = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:kLabelHeaderID forIndexPath:indexPath];
        retHeader = labelHeader;
    } else if (indexPath.section == kStyletFolderIDRecipes
               && ([self collectionView:collectionView numberOfItemsInSection:indexPath.section] == 0)) {
        NSError *error;
        NSString *headerFilePath = [[NSBundle mainBundle] pathForResource:@"Header_Recipes" ofType: @"txt"];
        NSString *headerText = [NSString stringWithContentsOfFile:headerFilePath encoding:NSUTF8StringEncoding error: &error];
        if (error)
            DDLogError(@"Error opening Header_Recipes.txt file: %@", error);
        LabelHeaderView *labelHeader = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:kRecipesHeaderID forIndexPath:indexPath];
        [labelHeader setHeaderText:headerText];
        retHeader = labelHeader;
    } else if (indexPath.section == kStyletFolderIDStore
               && ([self collectionView:collectionView numberOfItemsInSection:indexPath.section] == 0)) {
        StoreBannerView *storeBanner = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:kStoreBannerID forIndexPath:indexPath];
        [storeBanner.btnBuy addTarget:self action:@selector(onBuy:) forControlEvents:UIControlEventTouchUpInside];
        retHeader = storeBanner;
    }
    
    [self tellDataControllerWhatIsVisible];
    DDLogVerbose(@"Edit supplementary %@ at %@ returning %@", kind, indexPath, retHeader);
    return retHeader;
}

- (void)onBuy:(UIButton *)sender {
    if ([MKStoreManager featurePurchased1]) {
        return;
    }
    
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.labelText = @"Loading...";
    
    [MKStoreManager sharedManager].delegate = self;
    [[MKStoreManager sharedManager] buyFeature1];
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)view didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    ThumbnailAttributes* attrs = [self.dataController styletAttributesAtIndexPath:indexPath];
    if (attrs.isLocked) {
        [self showUnlockOptionsForStyletAt:indexPath];
    } else {
        [self.gridView setUserInteractionEnabled:NO];
        _animating = YES;
        _saveFolderBarFrame = self.folderBar.frame;
        [self.dataController applyStyletWithIndexPath:indexPath];
        [self.dataController rebuildCurrentThumbnails];

        [self updateHeaderAdjustment];
        [self animateFromGridCell:(EditGridViewCell *)[view cellForItemAtIndexPath:indexPath]];

        [self.beforeImageView setImage:[self.dataController previousPreview]];

        [self.strengthSlider setMinimumValue:0.0];
        [self.strengthSlider setMaximumValue:100.0];
        [self.strengthSlider setValue:100.0 animated:NO];
        [self.strengthSlider setEnabled:YES];
        [self.undoButton setEnabled:YES];
        [self.redoButton setEnabled:NO];

        if (! AppSettings.manager.appliedTwoFilters && [self.dataController appliedStepsCount] > 2) {
            [AppSettings.manager setAppliedTwoFilters:YES];
        }
    
        _visibleThumbnailsChanged = YES;
    }
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)calcPreviewHeaderSize {
    CGSize newHeaderSize = self.view.frame.size;
    newHeaderSize.height -= self.toolBar.frame.size.height - kDepthOfSmileyCurve + _previewHeightAdjustment;
    return newHeaderSize;
}

- (CGSize)collectionView:(UICollectionView *)collectionView
  layout:(UICollectionViewLayout*)collectionViewLayout
  referenceSizeForHeaderInSection:(NSInteger)section {
    DDLogVerbose(@"collectionView layout referenceSizeForItemAtIndexPath %zd", section);
    TRUNUSED UICollectionViewFlowLayout* layout =
      (UICollectionViewFlowLayout*)collectionViewLayout;
    if (section == 0) {
        // Don't use kStyletFolderIDXYZ constant above; it MUST always be the
        // first folder, whichever that is, even if kStyletFolder changes order.
        return [self calcPreviewHeaderSize];
    } else if (section == kStyletFolderIDHistory
               && [self sectionIsVisible:section]
               && ([self collectionView:collectionView numberOfItemsInSection:section] > 0)) {
        CGSize historyHeaderSize = CGSizeMake(self.view.frame.size.width, kHeightHistoryHeader);
        return historyHeaderSize;
    } else if (section == kStyletFolderIDRecipes
               && [self sectionIsVisible:section]
               && ([self collectionView:collectionView numberOfItemsInSection:section] == 0)) {
        CGSize recipesHeaderSize = CGSizeMake(self.view.frame.size.width, kHeightRecipesHeader);
        return recipesHeaderSize;
    } else if (section == kStyletFolderIDStore
               && [self sectionIsVisible:section]
               && ([self collectionView:collectionView numberOfItemsInSection:section] == 0)) {
        CGSize recipesHeaderSize = CGSizeMake(self.view.frame.size.width, kHeightStoreBanner);
        return recipesHeaderSize;
    }
    return CGSizeZero;
}

- (void)tellDataControllerWhatIsVisible {
    if (!_visibleThumbnailsChanged)
        return;
    
    [super tellDataControllerWhatIsVisible];
    _visibleThumbnailsChanged = NO;
}

#pragma mark - UIScrollViewDelegate

- (void)scrollStopped {
    _visibleThumbnailsChanged = YES;
    [self tellDataControllerWhatIsVisible];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self scrollSyncToolBar];
    [self scrollSyncFolderBar];
    [self scrollSyncNotification];
    _previousContentOffset = [scrollView contentOffset];
}

- (void)scrollViewWillBeginDecelerating:(UIScrollView*)scrollView {
    DDLogVerbose(@"scrollViewWillBeginDecelerating");
}

- (void)scrollViewDidEndDecelerating:(UIScrollView*)scrollView {
    DDLogVerbose(@"scrollViewDidEndDecelerating");
    [self scrollStopped];
}

- (void)scrollViewDidEndDragging:(UIScrollView*)scrollView willDecelerate:(BOOL)decelerate {
    DDLogVerbose(@"scrollViewDidEndDragging");
    if (!decelerate)
        [self scrollStopped];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    DDLogInfo(@"scrollViewDidEndScrollingAnimation");
}

#pragma mark - LXReorderableCollectionViewDelegateFlowLayout

- (void)collectionView:(UICollectionView *)theCollectionView
  layout:(UICollectionViewLayout *)theLayout
  didBeginDraggingItemAtIndexPath:(NSIndexPath *)theIndexPath {
    [self.folderBar setHidden:YES];
}

- (void)collectionView:(UICollectionView *)theCollectionView
  layout:(UICollectionViewLayout *)theLayout
  didEndDraggingItemAtIndexPath:(NSIndexPath *)theIndexPath {
    [self.folderBar setHidden:NO];
}

#pragma mark - AboutViewControllerDelegate

- (void)doCloseAboutView:(AboutViewController *)controller {
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (void)performTouchLibraryButton:(id)sender {
    [self.libraryButton sendActionsForControlEvents:UIControlEventTouchUpInside];
}

#pragma mark - MKStoreManagerDelegate

- (void)didBuyProduct1
{
    NSLog(@"didBuyProduct1");
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    
//    [self.dataController addStylet:@"Xra"];
//    [self.dataController addStylet:@"Xrb"];
//    [self.dataController addStylet:@"Xrc"];
//    [self.dataController addStylet:@"Xrd"];
//    [self.dataController addStylet:@"Xre"];
//    [self.dataController addStylet:@"Xrf"];
//    [self.dataController addStylet:@"Xrg"];
//    [self.dataController addStylet:@"Xrh"];
//    [self.dataController addStylet:@"Xri"];
//    [self.dataController addStylet:@"Xrj"];
    
    [self performSelector:@selector(performTouchLibraryButton:) withObject:nil afterDelay:0.5f];
}

- (void)didBuyProduct2
{
    NSLog(@"didBuyProduct2");
    [MBProgressHUD hideHUDForView:self.view animated:YES];
}

- (void)didCancelProduct
{
    NSLog(@"didCancelProduct");
    [MBProgressHUD hideHUDForView:self.view animated:YES];
}

- (void)didFailProductWithError:(NSError *)error
{
    NSLog(@"didFailProductWithError");
    [MBProgressHUD hideHUDForView:self.view animated:YES];
}

@end
