//
//  StyletViewController.m
//  RadLab
//
//  Created by Geoff Scott on 2/27/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import "StyletViewController.h"

#import "AboutViewController.h"
#import "AppSettings.h"
#import "ChooseImageViewController.h"
#import "EditGridViewCell.h"
#import "UICommon.h"

@interface StyletViewController ()
{
    NSArray* _visibleSections;
    NSInteger _initialSectionPreference;
}

@property (nonatomic, strong) UIPopoverController *picViewPopover;
@property (nonatomic, strong) UIPopoverController *aboutViewPopover;
@property (nonatomic, weak) UIPopoverController *currentOpenPopover;

@end

static NSString *kFilterCellID = @"filterGridID";
static const CGFloat kHeightRecipesHeader = 100.0;
static const CGFloat kHeightHistoryHeader = 24.0;

@implementation StyletViewController

@synthesize picViewPopover = _picViewPopover;
@synthesize aboutViewPopover = _aboutViewPopover;
@synthesize currentOpenPopover = _currentOpenPopover;

@synthesize dataController = _dataController;
@synthesize imageController = _imageController;
@synthesize sectionID = _sectionID;
@synthesize gridView = _gridView;
@synthesize folderTabsImageView = _folderTabsImageView;
@synthesize picButton = _aboutButton;
@synthesize aboutButton = _picButton;
@synthesize magicButton = _magicButton;
@synthesize recipeButton = _recipeButton;
@synthesize libraryButton = _libraryButton;

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _initialSectionPreference = AppSettings.manager.editViewInitialFolder;
    UIButton* initialButton = [self buttonForSection:_initialSectionPreference];
    [self setVisibleSections:initialButton];
    [self setActiveStyletFolder:initialButton];
    [self.magicButton setExclusiveTouch:YES];
    [self.recipeButton setExclusiveTouch:YES];
    [self.libraryButton setExclusiveTouch:YES];

    ChooseImageViewController *choose = [[ChooseImageViewController alloc] initWithNibName:@"Popover_Choose" bundle:nil];
    [choose setDataController:self.dataController];
    [choose setPopoverDelegate:self];
    UINavigationController *navigator = [[UINavigationController alloc] initWithRootViewController:choose];
    [navigator setToolbarHidden:YES];
    [navigator setNavigationBarHidden:YES];
    self.picViewPopover = [[UIPopoverController alloc] initWithContentViewController:navigator];
    self.picViewPopover.delegate = self;

    AboutViewController *about = [[AboutViewController alloc] initWithNibName:@"Popover_About" bundle:nil];
    [about setDataController:self.dataController];
    self.aboutViewPopover = [[UIPopoverController alloc] initWithContentViewController:about];
	self.aboutViewPopover.popoverContentSize = CGSizeMake(320.0, 500.0);
    self.aboutViewPopover.delegate = self;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(thumbnailIndexesRendered:) name:kNotificationThumbnailIndexRendered object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resetVisibleSections:) name:kNotificationResetStyletSections object:nil];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    addPinstripingToView(self.folderTabsImageView);

    if ([self.dataController hasEmptyMaster]) {
        [self doShowPopover:self.picViewPopover fromFrame:self.picButton.frame];
    }
}

- (void)resetVisibleSections:(NSNotification*)notification {
    _initialSectionPreference = AppSettings.manager.editViewInitialFolder;
    UIButton* initialButton = [self buttonForSection:_initialSectionPreference];
    [self setActiveStyletFolder:initialButton];
}

- (void)setVisibleSections:(UIButton*)button {
    if (button == _magicButton) {
        _visibleSections = [NSArray arrayWithObjects:
                            [NSNumber numberWithInt:kStyletFolderIDMagic],
                            nil];
    } else if (button == _recipeButton) {
        _visibleSections = [NSArray arrayWithObjects:
                            [NSNumber numberWithInt:kStyletFolderIDRecipes],
                            [NSNumber numberWithInt:kStyletFolderIDHistory],
                            nil];
    } else if (button == _libraryButton) {
        _visibleSections = [NSArray arrayWithObjects:
                            [NSNumber numberWithInt:kStyletFolderIDLibrary],
                            nil];
    }
}

- (void)setActiveStyletFolder:(UIButton*)sender {
    [self setVisibleSections:sender];
    
    [self.magicButton setEnabled:[self.dataController hasRecipesOrHistoryOrMagic]];
    [self.recipeButton setEnabled:[self.dataController hasRecipesOrHistoryOrMagic]];
    [self.libraryButton setEnabled:YES];
    
    NSString* section = nil;
    if (sender == _magicButton) {
        section = @"Magic";
        _recipeButton.selected = NO;
        _libraryButton.selected = NO;
        [self.folderTabsImageView setImage:[UIImage imageNamed:@"Tab_MyStyles"]];
    } else if (sender == _recipeButton) {
        section = @"Recipe";
        _magicButton.selected = NO;
        _libraryButton.selected = NO;
        [self.folderTabsImageView setImage:[UIImage imageNamed:@"Tab_Recipes"]];
    } else if (sender == _libraryButton) {
        section = @"Library";
        _magicButton.selected = NO;
        _recipeButton.selected = NO;
        if ([self.dataController hasRecipesOrHistoryOrMagic]) {
            [self.folderTabsImageView setImage:[UIImage imageNamed:@"Tab_Filters"]];
        } else {
            [self.folderTabsImageView setImage:[UIImage imageNamed:@"Tab_Initial"]];
        }
    }
    sender.selected = YES;
    
    [_gridView reloadData];
    [_gridView.collectionViewLayout invalidateLayout];
}

- (UIButton*)buttonForSection:(NSInteger)section {
    switch (section) {
        case kStyletFolderIDRecipes: return _recipeButton;
        case kStyletFolderIDHistory: return _recipeButton;
        case kStyletFolderIDMagic: return _magicButton;
        default: return _libraryButton;
    }
}

- (BOOL)sectionIsVisible:(NSInteger)section {
    return [_visibleSections containsObject:[NSNumber numberWithInteger:section]];
}

- (void)tellDataControllerWhatIsVisible {
    NSArray* visible = [self.gridView indexPathsForVisibleItems];
    NSMutableArray* actuallyVisible = [[NSMutableArray alloc] initWithCapacity:visible.count];
    for (NSIndexPath* p in visible) {
        if (![self cellIsHidden:p])
            [actuallyVisible addObject:p];
    }
    [self.dataController editViewNowShowingSections:[NSArray arrayWithObjects:[NSNumber numberWithInt:kStyletFolderIDLibrary], nil]
                                      andIndexPaths:actuallyVisible];
}

- (BOOL)cellIsHidden:(NSIndexPath*)indexPath {
    return ![self sectionIsVisible:indexPath.section];
}

- (void)thumbnailIndexesRendered:(NSNotification*)notification {
    if (!self.isViewLoaded || self.view.window == nil) {
        // do nothing if view is not on-screen
        return;
    }
    
    if (![NSThread isMainThread]) {
        [self performSelectorOnMainThread:@selector(thumbnailIndexesRendered:)
                               withObject:notification waitUntilDone:NO];
    } else {
        NSArray* visible = [self.gridView indexPathsForVisibleItems];
        NSArray* finished = [notification.userInfo valueForKey:@"indexes"];
        NSMutableSet* intersection = [NSMutableSet setWithArray:visible];
        [intersection intersectSet:[NSSet setWithArray:finished]];
        NSArray* refresh = [intersection allObjects];
        
        if (refresh.count > 0) {
            [self.gridView reloadItemsAtIndexPaths:refresh];
        }
    }
}

- (void)doShowPopover:(UIPopoverController *)controller fromFrame:(CGRect)sourceFrame {
    
    [self.currentOpenPopover dismissPopoverAnimated:YES];
    
    //	[controller presentPopoverFromRect:sourceFrame inView:self.view permittedArrowDirections:UIPopoverArrowDirectionDown animated:YES];
	[controller presentPopoverFromRect:sourceFrame inView:self.view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
    
    self.currentOpenPopover = controller;
}

- (IBAction)doShowPic:(id)sender {
    [self doShowPopover:self.picViewPopover fromFrame:self.picButton.frame];
}

- (IBAction)doShowAbout:(id)sender {
    [self doShowPopover:self.aboutViewPopover fromFrame:self.aboutButton.frame];
}

- (IBAction)doShowMagicStyletFolder:(id)sender {
    _initialSectionPreference = kStyletFolderIDMagic;
    [self setActiveStyletFolder:sender];
}

- (IBAction)doShowRecipeStyletFolder:(id)sender {
    _initialSectionPreference = kStyletFolderIDRecipes;
    [self setActiveStyletFolder:sender];
}

- (IBAction)doShowLibraryStyletFolder:(id)sender {
    _initialSectionPreference = kStyletFolderIDLibrary;
    [self setActiveStyletFolder:sender];
}

#pragma mark - EditViewPopoverDelegate

- (void)refresh {
    if ([self.dataController hasMaster]) {
        // geofftest - this needs work !!!
        
        if (![self.dataController isControllerSetup]) {
            [self.dataController setupController];
        }
        
        [self.imageController refreshImages];
        [self.gridView reloadData];
        [self resetVisibleSections:nil];
    }
}

- (void)dismissOpenPopover {
    [self.currentOpenPopover dismissPopoverAnimated:YES];
    self.currentOpenPopover = nil;
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView*)view {
    return 4;
}

- (NSInteger)collectionView:(UICollectionView*)view numberOfItemsInSection:(NSInteger)section {
    if (![self sectionIsVisible:section])
        return 1;
    return [self.dataController styletCountInSection:section];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    EditGridViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:kFilterCellID forIndexPath:indexPath];
    
    ThumbnailAttributes* attrs = [self.dataController styletAttributesAtIndexPath:indexPath];
    [cell setStyletName:attrs.name];
    [cell setCellType:attrs.type];

    UIImage* thumb = [self.dataController styletThumbnailAtIndexPath:indexPath];
    [cell setImage:thumb];
    [self tellDataControllerWhatIsVisible];
    
    return cell;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)view didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [self.gridView setUserInteractionEnabled:NO];

    [self.dataController applyStyletWithIndexPath:indexPath];    
    [self.dataController rebuildCurrentThumbnails];
    
    [self.imageController refreshImages];

    [self.gridView setUserInteractionEnabled:YES];
    [self.gridView reloadData];
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

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)calcPreviewHeaderSize {
    CGSize newHeaderSize = self.view.frame.size;
    newHeaderSize.height = 10;
    return newHeaderSize;
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout*)collectionViewLayout
referenceSizeForHeaderInSection:(NSInteger)section {
#if geofftest
    TRUNUSED UICollectionViewFlowLayout* layout = (UICollectionViewFlowLayout*)collectionViewLayout;
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
    }
#endif
    return CGSizeZero;
}

- (CGSize)collectionView:(UICollectionView*)collectionview
                  layout:(UICollectionViewLayout*)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath*)indexPath {
    //assert([self sectionIsVisible:indexPath.section]);
    UICollectionViewFlowLayout* layout =
    (UICollectionViewFlowLayout*)collectionViewLayout;
    if ([self sectionIsVisible:indexPath.section]) {
        return layout.itemSize;
    } else {
        return CGSizeMake(layout.itemSize.width, 0.0);
    }
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView
                        layout:(UICollectionViewLayout *)collectionViewLayout
        insetForSectionAtIndex:(NSInteger)section {
    UICollectionViewFlowLayout* layout =
    (UICollectionViewFlowLayout*)collectionViewLayout;
    if ([self sectionIsVisible:section]) {
        if (section == kStyletFolderIDHistory) {
            UIEdgeInsets insets = layout.sectionInset;
            insets.top = 15.0;
            return insets;
        } else if (section == kStyletFolderIDRecipes
                   && ([self collectionView:collectionView numberOfItemsInSection:section] == 0)) {
            UIEdgeInsets insets = layout.sectionInset;
            insets.top = 8.0;
            return insets;
        } else {
            return layout.sectionInset;
        }
    } else {
        // IMPORTANT: zero-height insets seem to cause the flow layout to
        // just reuse the previously held value of the section insets, so
        // when switching visibility of a section, zero-height insets result
        // in very weird behavior.  Use a "very short" one instead.
        static const UIEdgeInsets epsilon = {0, 0.01, 0.01, 0};
        return epsilon;
    }
}

- (CGFloat)collectionView:(UICollectionView *)collectionView
                   layout:(UICollectionViewLayout *)collectionViewLayout
minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    UICollectionViewFlowLayout* layout =
    (UICollectionViewFlowLayout*)collectionViewLayout;
    if ([self sectionIsVisible:section]) {
        return layout.minimumLineSpacing;
    } else {
        return 0.0;
    }
}

@end
