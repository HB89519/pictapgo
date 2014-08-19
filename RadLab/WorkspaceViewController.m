//
//  WorkspaceViewController.m
//  RadLab
//
//  Created by Geoff Scott on 7/15/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import "WorkspaceViewController.h"

#import "AboutViewController.h"
#import "AppSettings.h"
#import "ChooseImageViewController.h"
#import "EditGridViewCell.h"
#import "LabelHeaderView.h"
#import "TRStatistics.h"
#import <MobileCoreServices/UTCoreTypes.h>
#import "PTGNotify.h"
#import <QuartzCore/QuartzCore.h>
#import "Scaling.h"
#import "ShareViewController.h"
#import "UICommon.h"
#import "UIDevice-Hardware.h"
#import <libkern/OSAtomic.h>
#import "MemoryStatistics.h"
#import "EditGridHeaderView.h"
#import "StoreBannerView.h"
#import "MBProgressHUD.h"

// *** additional interface ***

@interface WorkspaceViewController ()

@property (nonatomic, weak) UIPopoverController *currentOpenPopover;
@property (nonatomic, weak) UIPopoverController *lastOpenPopover;
@property (nonatomic, strong) UIPopoverController *picViewPopover;
@property (nonatomic, strong) UIPopoverController *aboutViewPopover;
@property (nonatomic, strong) UIPopoverController *goViewPopover;

@end

// *** implementation ***

@implementation WorkspaceViewController

// public
@synthesize picButton = _aboutButton;
@synthesize aboutButton = _picButton;
@synthesize goButton = _goButton;

// private
@synthesize currentOpenPopover = _currentOpenPopover;
@synthesize lastOpenPopover = _lastOpenPopover;
@synthesize goViewPopover = _goViewPopover;
@synthesize picViewPopover = _picViewPopover;
@synthesize aboutViewPopover = _aboutViewPopover;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    ShareViewController *share = [[ShareViewController alloc] initWithNibName:@"Popover_Share" bundle:nil];
    [share setDataController:self.dataController];
    [share setPopoverDelegate:self];
    UINavigationController *navigator1 = [[UINavigationController alloc] initWithRootViewController:share];
    [navigator1 setToolbarHidden:YES];
    [navigator1 setNavigationBarHidden:YES];
    self.goViewPopover = [[UIPopoverController alloc] initWithContentViewController:navigator1];
    self.goViewPopover.delegate = self;
	self.goViewPopover.popoverContentSize = CGSizeMake(320.0, 390.0);

    ChooseImageViewController *choose = [[ChooseImageViewController alloc] initWithNibName:@"Popover_Choose" bundle:nil];
    [choose setDataController:self.dataController];
    [choose setPopoverDelegate:self];
    UINavigationController *navigator2 = [[UINavigationController alloc] initWithRootViewController:choose];
    [navigator2 setToolbarHidden:YES];
    [navigator2 setNavigationBarHidden:YES];
    self.picViewPopover = [[UIPopoverController alloc] initWithContentViewController:navigator2];
    self.picViewPopover.delegate = self;
    
    AboutViewController *about = [[AboutViewController alloc] initWithNibName:@"Popover_About" bundle:nil];
    [about setDataController:self.dataController];
    self.aboutViewPopover = [[UIPopoverController alloc] initWithContentViewController:about];
	self.aboutViewPopover.popoverContentSize = CGSizeMake(320.0, 500.0);
    self.aboutViewPopover.delegate = self;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self.toolBar setHidden:NO];

    if ([self.dataController hasEmptyMaster]) {
        [self doShowPopover:self.picViewPopover fromFrame:self.picButton.frame];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [self dismissOpenPopover];
    [super viewWillDisappear:animated];
}

- (void)setDataController:(ImageDataController *)controller {
    [super setDataController:controller];
    [controller setPreviewPresentationSize:[TapEditViewController previewSize]];
    [controller setThumbnailPresentationSize:[TapEditViewController thumbnailSize]];
}

- (void)resetStrengthSlider {
    [self.strengthSlider setMinimumValue:0.0];
    [self.strengthSlider setMaximumValue:100.0];
    [self.strengthSlider setValue:100.0 animated:NO];
    [self.strengthSlider setEnabled:[self.dataController currentStepIndex]];
    [self setAfterImageStrength:1.0];
}

- (void)refreshImages:(BOOL)bSetAfterImage {
    [self resetStrengthSlider];
    
    [self.beforeImageView setImage:[self.dataController previousPreview]];
    if (bSetAfterImage) {
        [self.afterImageView setImage:[self.dataController currentPreviewAtFullStrength]];
    }

    if (! AppSettings.manager.useSimpleBackground) {
        [self.blurredBackground setImage:blurImage([self.dataController masterPreview])];
    } else {
        [self.blurredBackground setImage:nil];
    }

    [self.undoButton setEnabled:[self.dataController currentStepIndex]];
    [self.redoButton setEnabled:NO];
    
    [self.goButton setEnabled:![self.dataController hasEmptyMaster]];
    [self.toolsButton setEnabled:![self.dataController hasEmptyMaster]];
}

- (IBAction)handleShortPress:(UILongPressGestureRecognizer *)recognizer {
    if ([PTGNotify isMessageCurrentlyDisplayed])
        return;

    BOOL bInsideImageView = NO;
    NSInteger behaviorPref;
    
    CGRect previewFrame = [self.view convertRect:self.beforeImageView.frame fromView:self.beforeImageView.superview];
    CGRect leftFrame = previewFrame;
    leftFrame.size.width = previewFrame.size.width / 2;
    CGRect rightFrame = previewFrame;
    rightFrame.size.width = leftFrame.size.width;
    rightFrame.origin.x += rightFrame.size.width;
    
    NSUInteger numTouches = [recognizer numberOfTouches];
    for (NSUInteger i = 0; i < numTouches; ++i ) {
		CGPoint location = [recognizer locationOfTouch:i inView:self.view];
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
            NSString *displayStr = NSLocalizedString(@"Previous", nil);
            if ((numTouches > 1 && behaviorPref == kLongPressShowsPrevious)
                || (numTouches == 1 && behaviorPref == kLongPressShowsOriginal)) {
                [self.beforeImageView setImage:[self.dataController masterPreview]];
                displayStr = NSLocalizedString(@"Original", nil);
            }
            [self.afterImageView setHidden:YES];
            [self displayBeforeString:displayStr onSide:behaviorPref == kLongPressShowsOriginal];
        }
    } else if ([recognizer state] == UIGestureRecognizerStateEnded) {
        [self.afterImageView setHidden:NO];
        [self.beforeImageView setImage:[self.dataController previousPreview]];
        [self dismissBeforeString];
    }
}

- (IBAction)handleLongPress:(UILongPressGestureRecognizer *)recognizer {
    if ([PTGNotify isMessageCurrentlyDisplayed])
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

- (CGRect)calcBeforeStringFrameFrom:(CGRect)labelFrame onSide:(BOOL)bLeftSide {
    CGRect previewFrame = [self.view convertRect:self.beforeImageView.frame fromView:self.beforeImageView.superview];
    CGRect retFrame = labelFrame;
    
    if (bLeftSide) {
        retFrame.origin.x = previewFrame.origin.x + 8.0;
    } else {
        retFrame.origin.x = previewFrame.origin.x + previewFrame.size.width - 8 - retFrame.size.width;
    }
    retFrame.origin.y = previewFrame.origin.y + 4;
    
    return retFrame;
}

- (IBAction)doReset:(id)sender {
    if ([self.dataController currentStepIndex] != 0) {
        [super doReset:sender];
        [self refreshImages:YES];
    }
}

- (void)animateUndoRedo:(BOOL)direction {
    NSInteger dirMod = 1;
    if (!direction)
        dirMod = -1;
    
    CGRect origImageFrame = [self.view convertRect:self.beforeImageView.frame fromView:self.beforeImageView.superview];
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
                         }
                     }];
}

- (CGRect)calculateDestRect {
    CGRect newFrame = [self.view convertRect:self.beforeImageView.frame fromView:self.beforeImageView.superview];    
    return newFrame;
}

- (void)animateFromGridCell:(EditGridViewCell *)startCell {
    // setup for moving the chosen grid cell
    UIImageView *newImageView = nil;
    UIImageView *startImageView = nil;
    CGRect currImageRect;
    if (startCell) {
        startImageView = startCell.imageView;
        float cellWidth = startImageView.frame.size.width;
        float cellHeight = startImageView.frame.size.height;
        currImageRect = CGRectMake(startCell.frame.origin.x + startCell.superview.frame.origin.x - self.gridView.contentOffset.x,
                                   startCell.frame.origin.y + startCell.superview.frame.origin.y - self.gridView.contentOffset.y,
                                   cellWidth, cellHeight);
        currImageRect = [self.view convertRect:currImageRect fromView:startCell.superview.superview];
    } else {
        startImageView = self.beforeImageView;
        currImageRect = startImageView.frame;
        currImageRect = [self.view convertRect:currImageRect fromView:self.beforeImageView.superview];
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
    [UIView animateWithDuration:0.5f
                          delay:0.0f
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         [newImageView setFrame:bigFrame];
                     }
                     completion:^(BOOL finished){
                         
                         if (finished) {
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
                             [UIView animateWithDuration:0.25f
                                                   delay:0.15f
                                                 options:UIViewAnimationOptionCurveEaseInOut
                                              animations:^{
                                                  [newImageView setFrame:newFrame];
                                              }
                                              completion:^(BOOL finished){
                                                  if (finished) {
                                                      [newImageView removeFromSuperview];
                                                      [self.gridView setUserInteractionEnabled:YES];
                                                      [self showSecondFilterNotification];
                                                  }
                                              }];
                         }
                     }
     ];
}

- (void)doShowPopover:(UIPopoverController *)controller fromFrame:(CGRect)sourceFrame {
    [self.currentOpenPopover dismissPopoverAnimated:YES];
    [controller presentPopoverFromRect:sourceFrame inView:self.view permittedArrowDirections:UIPopoverArrowDirectionLeft | UIPopoverArrowDirectionRight animated:YES];
    self.currentOpenPopover = controller;
}

- (IBAction)doShowPic:(id)sender {
    [self doShowPopover:self.picViewPopover fromFrame:self.picButton.frame];
}

- (IBAction)doShowGo:(id)sender {
    [self doShowPopover:self.goViewPopover fromFrame:self.goButton.frame];
}

- (IBAction)doShowAbout:(id)sender {
    [self doShowPopover:self.aboutViewPopover fromFrame:self.aboutButton.frame];
}

#pragma mark - UIPopoverControllerDelegate

- (BOOL)popoverControllerShouldDismissPopover:(UIPopoverController *)popoverController {
    if (popoverController == self.goViewPopover) {
        // don't leave the Go screen on the Save Recipe screen
        UINavigationController *navController = (UINavigationController*)self.goViewPopover.contentViewController;
        [navController popToRootViewControllerAnimated:YES];
    }
    
    return YES;
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController {
    self.lastOpenPopover = self.currentOpenPopover;
    self.currentOpenPopover = nil;
    
    if (self.lastOpenPopover == self.aboutViewPopover) {
        if (! AppSettings.manager.useSimpleBackground) {
            [self.blurredBackground setImage:blurImage([self.dataController masterPreview])];
        } else {
            [self.blurredBackground setImage:nil];
        }
    }
}

#pragma mark - WorkspaceViewPopoverDelegate

- (void)refresh {
    if ([self.dataController hasMaster]) {
        [self refreshImages:YES];
        [self.gridView reloadData];
        [self resetVisibleSections:nil];
        if (! AppSettings.manager.visitedTapScreen && ![self.dataController hasEmptyMaster]) {
            [PTGNotify displayInitialHelp:@"Help_Tap" withAlertTitle:NSLocalizedString(@"STYLE IT", nil) pageNumber:2 ofTotalPageCount:4 withButtonTitle:NSLocalizedString(@"Start Tapping!", nil) aboveViewController:self];
            AppSettings.manager.visitedTapScreen = YES;
        }
    }
}

- (void)dismissOpenPopover {
    [self.currentOpenPopover dismissPopoverAnimated:YES];
    self.lastOpenPopover = self.currentOpenPopover;
    self.currentOpenPopover = nil;
}

- (void)reopenLastPopover {
    if (self.lastOpenPopover == self.goViewPopover) {
        [self doShowGo:self];
    } else if (self.lastOpenPopover == self.picViewPopover) {
        [self doShowPic:self];
    } else if (self.lastOpenPopover == self.aboutViewPopover) {
        [self doShowAbout:self];
    }
}

- (void)showHelpScreen:(NSString*)urlString {
    [self dismissOpenPopover];
    AboutViewController *about = (AboutViewController*) [self.aboutViewPopover contentViewController];
    about.navigation = [AboutViewNavigation newHelpURL:urlString];
    [self doShowAbout:self];
}

#pragma mark - UICollectionViewDataSource

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    UICollectionReusableView *retHeader = nil;
    
    StoreBannerView *storeBanner = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:kStoreBannerID forIndexPath:indexPath];
    CGRect frame = storeBanner.btnBuy.frame;
    frame.origin.y = 10.0f;
    storeBanner.btnBuy.frame = frame;
    [storeBanner.btnBuy addTarget:self action:@selector(onBuy:) forControlEvents:UIControlEventTouchUpInside];
    retHeader = storeBanner;
    
    [self tellDataControllerWhatIsVisible];
    return retHeader;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)view didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (![self.dataController hasEmptyMaster]) {
        ThumbnailAttributes* attrs = [self.dataController styletAttributesAtIndexPath:indexPath];
        if (attrs.isLocked) {
            [self showUnlockOptionsForStyletAt:indexPath];
        } else {
            [self.gridView setUserInteractionEnabled:NO];
    
            [self.dataController applyStyletWithIndexPath:indexPath];
            [self.dataController rebuildCurrentThumbnails];
    
            [self animateFromGridCell:(EditGridViewCell *)[view cellForItemAtIndexPath:indexPath]];
            [self refreshImages:NO];
    
            [self.gridView reloadData];
        }
    }
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout
referenceSizeForHeaderInSection:(NSInteger)section {
    TRUNUSED UICollectionViewFlowLayout* layout = (UICollectionViewFlowLayout*)collectionViewLayout;
    if (section == kStyletFolderIDStore && [self sectionIsVisible:section] && ([self collectionView:collectionView numberOfItemsInSection:section] == 0)) {
        CGSize recipesHeaderSize = CGSizeMake(self.view.frame.size.width, 130.0f);
        return recipesHeaderSize;
    }
    else {
        return CGSizeZero;
    }
}

#pragma mark - ToolViewControllerDelegate

- (void)doCloseToolView:(ToolViewController *)controller {
    [super doCloseToolView:controller];
    [self refreshImages:YES];
    [self.dataController rebuildCurrentThumbnails];
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

- (void)performTouchLibraryButton:(id)sender {
    [self.libraryButton sendActionsForControlEvents:UIControlEventTouchUpInside];
}

#pragma mark - MKStoreManagerDelegate

- (void)didBuyProduct1
{
    NSLog(@"didBuyProduct1");
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    
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
