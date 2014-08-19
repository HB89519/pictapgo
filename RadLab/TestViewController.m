//
//  TestViewController.m
//  RadLab
//
//  Created by Geoff Scott on 2/25/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import "TestViewController.h"

#import "AppSettings.h"
#import "ChooseImageViewController.h"
#import "EditGridHeaderView.h"
#import "EditGridViewCell.h"
#import "ShareViewController.h"
#import "StyletViewController.h"
#import "UICommon.h"
#import "UIDevice-Hardware.h"

@interface TestViewController ()
{
    NSInteger _initialSectionPreference;
}

@property (nonatomic, strong) UIPopoverController *aboutViewPopover;
@property (nonatomic, strong) UIPopoverController *picViewPopover;
@property (nonatomic, strong) UIPopoverController *goViewPopover;
@property (nonatomic, strong) UIPopoverController *recipeViewPopover;
@property (nonatomic, strong) UIPopoverController *myStylesPopover;
@property (nonatomic, strong) UIPopoverController *recipeStylesPopover;
@property (nonatomic, strong) UIPopoverController *filterStylesPopover;

@property (nonatomic, weak) UIPopoverController *currentOpenPopover;

@end

static NSString *kFilterCellID = @"filterGridID";
static NSString *kFilterHeaderID = @"filterGridHeader";

@implementation TestViewController

@synthesize aboutViewPopover = _aboutViewPopover;
@synthesize picViewPopover = _picViewPopover;
@synthesize goViewPopover = _goViewPopover;
@synthesize recipeViewPopover = _recipeViewPopover;
@synthesize currentOpenPopover = _currentOpenPopover;
@synthesize myStylesPopover = _myStylesPopover;
@synthesize recipeStylesPopover = _recipeStylesPopover;
@synthesize filterStylesPopover = _filterStylesPopover;

@synthesize dataController = _dataController;
@synthesize aboutButton = _aboutButton;
@synthesize picButton = _picButton;
@synthesize goButton = _goButton;
@synthesize recipeButton = _recipeButton;
@synthesize gridView = _gridView;
@synthesize afterImageView = _afterImageView;
@synthesize beforeImageView = _beforeImageView;
@synthesize folderBar = _folderBar;
@synthesize folderTabsImageView = _folderTabsImageView;
@synthesize magicFolderButton = _magicFolderButton;
@synthesize recipeFolderButton = _recipeFolderButton;
@synthesize libraryFolderButton = _libraryFolderButton;
@synthesize toolBar = _toolBar;
@synthesize strengthSlider = _strengthSlider;
@synthesize undoButton = _undoButton;
@synthesize redoButton = _redoButton;

- (CGSize)thumbnailSize {
    // IMPORTANT: keep this in sync with the storyboard!
    // iPhone numbers are from the storyboard. iPad = x2
    
    // geofftest: note commented out if is when there is a real iPad interface being used.
    // Currently checking the device instead. Not recommended by Apple as a long term solution.
    // if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    if ([[UIDevice currentDevice] deviceFamily] == UIDeviceFamilyiPad)
        return CGSizeMake(188, 188);
    else
        return CGSizeMake(94, 94);
}

- (CGSize)previewSize {
    // IMPORTANT: keep this in sync with the storyboard!
    // iPhone numbers are from the storyboard. iPad = x2
    
    // geofftest: note commented out if is when there is a real iPad interface being used.
    // Currently checking the device instead. Not recommended by Apple as a long term solution.
    // if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    if ([[UIDevice currentDevice] deviceFamily] == UIDeviceFamilyiPad)
        return CGSizeMake(608, 856);
    else
        return CGSizeMake(304, 428);
}

- (void)setActiveStyletFolder:(NSInteger)section {
    _initialSectionPreference = section;

//    [self.magicFolderButton setEnabled:[self.dataController hasRecipesOrHistoryOrMagic]];
    [self.magicFolderButton setEnabled:YES];
//    [self.recipeFolderButton setEnabled:[self.dataController hasRecipesOrHistoryOrMagic]];
    [self.recipeFolderButton setEnabled:YES];
    [self.libraryFolderButton setEnabled:YES];
    
    switch (section) {
        case kStyletFolderIDMagic:
            [self.folderTabsImageView setImage:[UIImage imageNamed:@"Tab_MyStyles"]];
            break;
            
        case kStyletFolderIDRecipes:
            [self.folderTabsImageView setImage:[UIImage imageNamed:@"Tab_Recipes"]];
            break;
            
        case kStyletFolderIDLibrary:
//            if ([self.dataController hasRecipesOrHistoryOrMagic]) {
                [self.folderTabsImageView setImage:[UIImage imageNamed:@"Tab_Filters"]];
//            } else {
//                [self.folderTabsImageView setImage:[UIImage imageNamed:@"Tab_Initial"]];
//            }
            break;
            
        default:
            break;
    }
    
    [self refresh];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    addPinstripingToView(self.view);
    
    _initialSectionPreference = AppSettings.manager.editViewInitialFolder;
    
    [self.strengthSlider setEnabled:NO];
    [self.strengthSlider setMinimumValue:0.0];
    [self.strengthSlider setMaximumValue:100.0];
    [self.strengthSlider setDefaultValue:100.0];
    [self.strengthSlider setValue:100.0];
    
    [self.undoButton setDelegate:self];
    [self.undoButton setEnabled:NO];
    [self.redoButton setEnabled:NO];

    self.currentOpenPopover = nil;
    
    AboutViewController *about = [[AboutViewController alloc] initWithNibName:@"Popover_About" bundle:nil];
    [about setDelegate:self];
    self.aboutViewPopover = [[UIPopoverController alloc] initWithContentViewController:about];
	self.aboutViewPopover.popoverContentSize = CGSizeMake(320.0, 500.0);
    self.aboutViewPopover.delegate = self;

    ChooseImageViewController *choose = [[ChooseImageViewController alloc] initWithNibName:@"Popover_Choose" bundle:nil];
    [choose setDataController:self.dataController];
    [choose setPopoverDelegate:self];
    UINavigationController *navigator = [[UINavigationController alloc] initWithRootViewController:choose];
    [navigator setToolbarHidden:YES];
    [navigator setNavigationBarHidden:YES];
    self.picViewPopover = [[UIPopoverController alloc] initWithContentViewController:navigator];
    self.picViewPopover.delegate = self;
    
    ShareViewController *share = [[ShareViewController alloc] initWithNibName:@"Popover_Share" bundle:nil];
    [share setDataController:self.dataController];
    self.goViewPopover = [[UIPopoverController alloc] initWithContentViewController:share];
    self.goViewPopover.delegate = self;

    StyletViewController *myStyles = [[StyletViewController alloc] initWithNibName:@"Popover_Filters" bundle:nil];
    [myStyles setDataController:self.dataController];
    [myStyles setPopoverDelegate:self];
    [myStyles setSectionID:kStyletFolderIDMagic];
    self.myStylesPopover = [[UIPopoverController alloc] initWithContentViewController:myStyles];
    self.myStylesPopover.delegate = self;
    
    StyletViewController *myRecipes = [[StyletViewController alloc] initWithNibName:@"Popover_Filters" bundle:nil];
    [myRecipes setDataController:self.dataController];
    [myRecipes setPopoverDelegate:self];
    [myRecipes setSectionID:kStyletFolderIDRecipes];
    self.recipeStylesPopover = [[UIPopoverController alloc] initWithContentViewController:myRecipes];
    self.recipeStylesPopover.delegate = self;
    
    StyletViewController *myFilters = [[StyletViewController alloc] initWithNibName:@"Popover_Filters" bundle:nil];
    [myFilters setDataController:self.dataController];
    [myFilters setPopoverDelegate:self];
    [myFilters setSectionID:kStyletFolderIDLibrary];
    self.filterStylesPopover = [[UIPopoverController alloc] initWithContentViewController:myFilters];
    self.filterStylesPopover.delegate = self;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    // make the strength slider smile
	[self.strengthSlider setThumbImage:[UIImage imageNamed:@"Slider_ThumbDisabled.png"] forState:UIControlStateDisabled];
	[self.strengthSlider setThumbImage:[UIImage imageNamed:@"Slider_Thumb.png"] forState:UIControlStateNormal];
	[self.strengthSlider setMaximumTrackImage:[UIImage imageNamed:@"SliderTrack_MaxDisabled.png"] forState:UIControlStateDisabled];
	[self.strengthSlider setMaximumTrackImage:[UIImage imageNamed:@"SliderTrack_Max.png"] forState:UIControlStateNormal];
	[self.strengthSlider setMinimumTrackImage:[UIImage imageNamed:@"SliderTrack_MinDisabled.png"] forState:UIControlStateDisabled];
	[self.strengthSlider setMinimumTrackImage:[UIImage imageNamed:@"SliderTrack_Min.png"] forState:UIControlStateNormal];
    if ([self.dataController currentStepIndex] > 0) {
        [self.strengthSlider setEnabled:YES];
    } else {
        [self.strengthSlider setEnabled:NO];
    }
//    self.redoButton.enabled = !self.currentlyAtLastStep;
    
    addMaskToToolBar(self.toolBar);

#if geofftest
    if (![self.dataController hasMaster])
        [self doShowPopover:self.picViewPopover fromFrame:self.picButton.frame];
#endif
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)doShowPopover:(UIPopoverController *)controller fromFrame:(CGRect)sourceFrame {
    
    [self.currentOpenPopover dismissPopoverAnimated:YES];
   
//	[controller presentPopoverFromRect:sourceFrame inView:self.view permittedArrowDirections:UIPopoverArrowDirectionDown animated:YES];
	[controller presentPopoverFromRect:sourceFrame inView:self.view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
    
    self.currentOpenPopover = controller;
}

- (IBAction)doShowAbout:(id)sender {
    [self doShowPopover:self.aboutViewPopover fromFrame:self.aboutButton.frame];
}

- (IBAction)doShowPic:(id)sender {
    [self doShowPopover:self.picViewPopover fromFrame:self.picButton.frame];
}

- (IBAction)doShowGo:(id)sender {
    [self doShowPopover:self.goViewPopover fromFrame:self.goButton.frame];
}

- (IBAction)doShowRecipe:(id)sender {
    [self doShowPopover:self.recipeViewPopover fromFrame:self.recipeButton.frame];
}

- (IBAction)doShowMagicStyletFolder:(id)sender {
    [self setActiveStyletFolder:kStyletFolderIDMagic];
    [self doShowPopover:self.myStylesPopover fromFrame:self.folderBar.frame];
}

- (IBAction)doShowRecipeStyletFolder:(id)sender {
    [self setActiveStyletFolder:kStyletFolderIDRecipes];
    [self doShowPopover:self.recipeStylesPopover fromFrame:self.folderBar.frame];
}

- (IBAction)doShowLibraryStyletFolder:(id)sender {
    [self setActiveStyletFolder:kStyletFolderIDLibrary];
    [self doShowPopover:self.filterStylesPopover fromFrame:self.folderBar.frame];
}

- (IBAction)doReset:(id)sender {
    
}

- (IBAction)doUndo:(id)sender {
    
}

- (IBAction)doRedo:(id)sender {
    
}

- (IBAction)doSliderValueChanged:(PTGSlider *)sender {
    
}

- (IBAction)doSliderStopped:(PTGSlider *)sender {
    
}

#pragma mark - ImageDataControllerDelegate

- (void)setDataController:(ImageDataController *)controller {
    _dataController = controller;
    [controller setPreviewPresentationSize:self.previewSize];
    [controller setThumbnailPresentationSize:self.thumbnailSize];
}

#pragma mark - EditViewPopoverDelegate

- (void)refresh {
    if ([self.dataController hasMaster]) {
        // geofftest - this needs work !!!
        
        if (![self.dataController isControllerSetup]) {
            [self.dataController setupController];
        }
        [self.beforeImageView setImage:[self.dataController previousPreview]];
        [self.afterImageView setImage:[self.dataController currentPreviewAtFullStrength]];
//        [self.gridView reloadData];
    }
}

- (void)dismissOpenPopover {
    [self.currentOpenPopover dismissPopoverAnimated:YES];
    self.currentOpenPopover = nil;
    [self refresh];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView*)view {
// geofftest    return 4;
    return 1;
}

- (NSInteger)collectionView:(UICollectionView*)view numberOfItemsInSection:(NSInteger)section {
    if ([self.dataController hasMaster]) {
        section = kStyletFolderIDLibrary;       // geofftest
        return [self.dataController styletCountInSection:section];
    } else {
        return 0;
    }
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    NSIndexPath *tempPath = [NSIndexPath indexPathForItem:indexPath.item inSection:kStyletFolderIDLibrary];     // geofftest
    
    EditGridViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:kFilterCellID forIndexPath:indexPath];
    
    ThumbnailAttributes* attrs = [self.dataController styletAttributesAtIndexPath:tempPath];
    [cell setStyletName:attrs.name];
    [cell setCellType:attrs.type];
#if geofftest
    UIImage* thumb = [self.dataController styletThumbnailAtIndexPath:tempPath
                                                 withCompletionBlock:^(void){
                                                     dispatch_async(dispatch_get_main_queue(), ^{
                                                         NSArray* visible = [self.gridView indexPathsForVisibleItems];
                                                         if ([visible containsObject:indexPath]) {
// geofftest                                                             _animating = YES;
                                                             [self.gridView reloadItemsAtIndexPaths:[NSArray arrayWithObject:indexPath]];
// geofftest                                                             _animating = NO;
                                                         }
                                                     });
                                                 }];
#else
    UIImage* thumb = [self.dataController styletThumbnailAtIndexPath:indexPath];
#endif
    [cell setImage:thumb];
    
// geofftest    [self tellDataControllerWhatIsVisible];
    return cell;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    UICollectionReusableView *retHeader = nil;
    
    if (indexPath.section == 0) {
        EditGridHeaderView *header = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:kFilterHeaderID forIndexPath:indexPath];
// geofftest        if (! _animating) {
        if ([self.dataController hasMaster]) {
            [header.beforeImageView setImage:[self.dataController previousPreview]];
            [header.afterImageView setImage:[self.dataController currentPreviewAtFullStrength]];
        }
        
        addPinstripingToView(header);
        
        [self setBeforeImageView:header.beforeImageView];
        setPreviewStylingForView(self.beforeImageView);
        
        [self setAfterImageView:header.afterImageView];
        retHeader = header;
#if geofftest
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
            NSLog(@"Error opening Header_Recipes.txt file: %@", error);
        LabelHeaderView *labelHeader = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:kRecipesHeaderID forIndexPath:indexPath];
        [labelHeader setHeaderText:headerText];
        retHeader = labelHeader;
#endif
    }
    
    return retHeader;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)view didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [self.gridView setUserInteractionEnabled:NO];
#if geofftest
    _animating = YES;
    _saveFolderBarFrame = self.folderBar.frame;
    [self.dataController applyStyletWithIndexPath:indexPath];
    [self updateHeaderAdjustment];
    [self animateFromGridCell:(EditGridViewCell *)[view cellForItemAtIndexPath:indexPath]];
    
    [self.beforeImageView setImage:[self.dataController previousPreview]];

    [self.strengthSlider setMinimumValue:0.0];
    [self.strengthSlider setMaximumValue:100.0];
    [self.strengthSlider setValue:100.0 animated:NO];
    [self.strengthSlider setEnabled:YES];
    [self.undoButton setEnabled:YES];
    [self.redoButton setEnabled:NO];
#else
    NSIndexPath *tempPath = [NSIndexPath indexPathForItem:indexPath.item inSection:kStyletFolderIDLibrary];     // geofftest
    [self.dataController applyStyletWithIndexPath:tempPath];
    [self.gridView setContentOffset:CGPointZero];
    
    UIImage* image = [self.dataController currentPreviewAtFullStrength];
    [self.afterImageView setImage:image];
    [self.beforeImageView setImage:[self.dataController previousPreview]];
    [self.gridView setUserInteractionEnabled:YES];
    [self.gridView reloadData];
#endif
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldHighlightItemAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)collectionView:(UICollectionView *)collectionView didHighlightItemAtIndexPath:(NSIndexPath *)indexPath {
    EditGridViewCell* cell = (EditGridViewCell *)[collectionView cellForItemAtIndexPath:indexPath];
    [cell.imageView setAlpha:0.5];
}

- (void)collectionView:(UICollectionView *)collectionView didUnhighlightItemAtIndexPath:(NSIndexPath *)indexPath {
    EditGridViewCell* cell = (EditGridViewCell *)[collectionView cellForItemAtIndexPath:indexPath];
    [cell.imageView setAlpha:1.0];
}

#pragma mark - UIPopoverControllerDelegate

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController {
    self.currentOpenPopover = nil;
    [self refresh];
}

- (BOOL)popoverControllerShouldDismissPopover:(UIPopoverController *)popoverController {
    return YES;
}

#pragma mark - PTGButtonDelegate

- (void)PTGButtonDelegateLongPress:(PTGButton *)sourceButton {
    [self doReset:self];
}

#pragma mark - AboutViewControllerDelegate

- (void)resetStyletList:(AboutViewController *)controller {
    [self.dataController resetStyletList];
}

- (void)resetMagic:(AboutViewController*)controller {
    [self.dataController resetMagic];
}

- (void)deleteAllRecipes:(AboutViewController*)controller {
    [self.dataController deleteAllRecipes];
}

- (void)deleteAllHistory:(AboutViewController*)controller {
    [self.dataController deleteAllHistory];
}

- (void)resetHelpMessages:(AboutViewController*)controller {
    [[AppSettings manager] setVisitedPicScreen:NO];
    [[AppSettings manager] setVisitedTapScreen:NO];
    [[AppSettings manager] setVisitedGoScreen:NO];
}

- (void)resetEverything:(AboutViewController*)controller {
    [self.dataController resetStyletList];
    [self.dataController resetMagic];
    [self.dataController deleteAllRecipes];
    [self.dataController deleteAllHistory];
    [AppSettings resetToDefaults];
}

- (void)doCloseAboutView:(AboutViewController *)controller {
    
}

@end
