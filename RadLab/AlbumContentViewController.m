//
//  AlbumContentViewController.m
//  RadLab
//
//  Created by Geoff Scott on 12/7/12.
//  Copyright (c) 2012 Totally Rad. All rights reserved.
//

#import "AlbumContentViewController.h"

#import "AppSettings.h"
#import "ChooseImageCell.h"
#import "ChooseImageFooter.h"
#import "EditGridViewController.h"
#import "MemoryStatistics.h"
#import "TRImageProvider.h"
#import "UICommon.h"

static const int ddLogLevel = LOG_LEVEL_VERBOSE;

@interface AlbumContentViewController () <UICollectionViewDataSource>
{
    int _viewLoadCount;
    NSMutableArray* _photoList;
    NSURL* _assetsGroupURL;
    NSConditionLock* _fillListLock;
    NSIndexPath* _scrollIndex;
}
@property (atomic) BOOL reloadAssets;
@property (strong) ALAssetsLibrary* assetsLibrary;
@end

NSString *kAlbumImageCellID = @"imageGridID";
NSString *kAlbumImageHeaderID = @"imageGridFooter";

@implementation AlbumContentViewController

@synthesize popoverDelegate = _popoverDelegate;
@synthesize dataController = _dataController;
@synthesize gridView = _gridView;
@synthesize editButton = _editButton;
@synthesize navImageBack = _navImageBack;

- (void)dealloc {
    _photoList = nil;
    _assetsGroupURL = nil;
    _scrollIndex = nil;
    _fillListLock = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

enum AssetListLoadingCondition {COND_READY, COND_RUNNING};

- (void)firstTimeInitialization {
    _scrollIndex = nil;
    _fillListLock = [[NSConditionLock alloc] initWithCondition:COND_READY];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    if (_viewLoadCount++ == 0)
        [self firstTimeInitialization];

    [[NSNotificationCenter defaultCenter] addObserver:self
      selector:@selector(assetsLibraryChanged:)
      name:ALAssetsLibraryChangedNotification
      object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
      selector:@selector(applicationWillEnterForeground:)
      name:UIApplicationWillEnterForegroundNotification
      object:nil];

    _photoList = [[NSMutableArray alloc] init];
    self.reloadAssets = YES;

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.gridView registerNib:[UINib nibWithNibName:@"Cell_ChooseGridView" bundle:[NSBundle mainBundle]] forCellWithReuseIdentifier:kAlbumImageCellID];
        [self.gridView registerNib:[UINib nibWithNibName:@"Footer_ChooseGridView" bundle:[NSBundle mainBundle]] forSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:kAlbumImageHeaderID];
    }
    
    self.assetsLibrary = [[ALAssetsLibrary alloc] init];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self startFillingAssetList];
    [self.editButton setEnabled:[self.dataController hasMaster]];

    if (AppSettings.manager.useSimpleBackground) {
        [self.navImageBack setAlpha:1.0];
    } else {
        [self.navImageBack setAlpha:0.65];
    }
}

- (void)my_viewWillUnload {
    DDLogInfo(@"begin will unload AlbumContent view (mem %@)", stringWithMemoryInfo());
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_photoList removeAllObjects];
    self.assetsLibrary = nil;
    DDLogInfo(@"finished will unload AlbumContent view (mem %@)", stringWithMemoryInfo());
}

- (void)my_viewDidUnload {
    DDLogError(@"did unload AlbumContent view");
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    if (self.isViewLoaded && self.view.window == nil) {
        [self my_viewWillUnload];
        self.view = nil;
        [self my_viewDidUnload];
    }
}

- (void)reloadAssetsLibrary {
    DDLogInfo(@"AlbumContentViewController reloadAssetsLibrary");
    self.reloadAssets = YES;
    [self startFillingAssetList];
}

- (void)assetsLibraryChanged:(NSNotification*)notification {
    DDLogInfo(@"AlbumContentViewController assetsLibraryChanged");
    self.reloadAssets = YES;
    if (self.isViewLoaded && self.view.window != nil) {
        [self reloadAssetsLibrary];
    }
}

- (void)applicationWillEnterForeground:(NSNotification*)notification {
    DDLogInfo(@"AlbumContentViewController applicationWillEnterForeground");
    if (self.isViewLoaded && self.view.window != nil) {
        [self reloadAssetsLibrary];
    }
}

- (void)setAssetsGroup:(ALAssetsGroup*)assetsGroup {
    // Remember the persistent URL for the group
    _assetsGroupURL = [assetsGroup valueForProperty:ALAssetsGroupPropertyURL];
}

- (void)makeUICurrentWithLists {
    [self.gridView reloadData];

    for (int i = 0; i < 2; ++i) {
        if (!_scrollIndex) {
            NSUInteger maxSection = [self.gridView numberOfSections];
            NSUInteger maxItem = [self.gridView numberOfItemsInSection:maxSection - 1];
            _scrollIndex = [NSIndexPath indexPathForItem:maxItem - 1 inSection:maxSection - 1];
            DDLogInfo(@"Initialized scrollIndex to %zd,%zd", maxSection - 1, maxItem - 1);
        }
        @try {
            if (_scrollIndex.section >= 0 && _scrollIndex.row >= 0) {
                // try to scroll to the saved index
                [self.gridView scrollToItemAtIndexPath:_scrollIndex
                  atScrollPosition:UICollectionViewScrollPositionCenteredVertically
                  animated:NO];
            }
            // if scroll succeeded, we're done
            break;
        }
        @catch (NSException* x) {
            // scroll failed, so loop again which will scroll to end
            _scrollIndex = nil;
        }
    }
}

- (void)startFillingAssetList {
    if (!self.reloadAssets) {
        DDLogInfo(@"assets haven't changed");
        return;
    }

    DDLogVerbose(@"startFillingAssetList fillListLock %zd", _fillListLock.condition);
    if (![_fillListLock tryLockWhenCondition:COND_READY]) {
        DDLogInfo(@"assets list fill operation already running");
        return;
    }
    [_fillListLock unlockWithCondition:COND_RUNNING];
    DDLogVerbose(@"startFillingAssetList fillListLock now %zd", _fillListLock.condition);
    [self fillPhotoList];
}

- (void)doneFillingAssetList:(NSArray*)pList {
    @autoreleasepool {
        NSArray* sortedList = [pList sortedArrayUsingComparator:^(ALAsset* obj1, ALAsset* obj2) {
            NSDate *photoDate1;
            NSDate *photoDate2;
            [obj1.defaultRepresentation.url getResourceValue:&photoDate1 forKey:NSURLContentModificationDateKey error:nil];
            [obj2.defaultRepresentation.url getResourceValue:&photoDate2 forKey:NSURLContentModificationDateKey error:nil];
            return [photoDate1 compare:photoDate2];
        }];
        [_photoList removeAllObjects];
        [_photoList addObjectsFromArray:sortedList];

        DDLogVerbose(@"doneFillingAssetList fillListsLock %zd", _fillListLock.condition);
        [_fillListLock lockWhenCondition:COND_RUNNING];
        [_fillListLock unlockWithCondition:COND_READY];
        DDLogVerbose(@"doneFillingAssetList fillListsLock now %zd", _fillListLock.condition);
        self.reloadAssets = NO;
        [self makeUICurrentWithLists];
    }
}

- (void)fillPhotoList {
    [_photoList removeAllObjects];

    __block AlbumContentViewController* mySelf = self;
    __block NSMutableArray* pList = [[NSMutableArray alloc] init];
    ALAssetsLibraryGroupResultBlock assetsGroupBlock = ^(ALAssetsGroup* group) {
        [group setAssetsFilter:[ALAssetsFilter allPhotos]];
        [group enumerateAssetsUsingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {
            // Always ends with call of null asset, so reload data then
            if (result) {
                [pList addObject:result];
            } else {
                [mySelf performSelectorOnMainThread:@selector(doneFillingAssetList:) withObject:pList waitUntilDone:YES];
                mySelf = nil;
                pList = nil;
            }
        }];
    };

    ALAssetsLibraryAccessFailureBlock failureBlock = ^(NSError* error) {
        DDLogError(@"Problem accessing the assets library");
    };
    
    [self.assetsLibrary groupForURL:_assetsGroupURL
      resultBlock:assetsGroupBlock failureBlock:failureBlock];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    DDLogInfo(@"AlbumContentViewController prepareForSegue %@", segue.identifier);
    if ([[segue identifier] isEqualToString:@"showEditorGrid"]) {
        EditGridViewController *editController = (EditGridViewController *)[segue destinationViewController];
        [editController setDataController:self.dataController];
    }
}

- (IBAction)doBack:(id)sender {
    UINavigationController *navCon = [self navigationController];
    [navCon popViewControllerAnimated:YES];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)view numberOfItemsInSection:(NSInteger)section; {
    return [_photoList count];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)indexPath; {
    ChooseImageCell *cell = [cv dequeueReusableCellWithReuseIdentifier:kAlbumImageCellID forIndexPath:indexPath];
    
    ALAsset *asset = [_photoList objectAtIndex:indexPath.row];
    CGImageRef thumbnailImageRef = [asset thumbnail];
    UIImage *thumbnail = [UIImage imageWithCGImage:thumbnailImageRef];
    [cell setImage:thumbnail];
    
    return cell;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    ChooseImageFooter *footer = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:kAlbumImageHeaderID forIndexPath:indexPath];
    NSInteger count = _photoList.count;
    [footer.imageCountLabel setText:(count == 1 ? NSLocalizedString(@"1 Photo", nil) :
                                        [NSString stringWithFormat:NSLocalizedString(@"%d Photos", nil), count])];

    return footer;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    _scrollIndex = indexPath;
    [self.gridView scrollToItemAtIndexPath:_scrollIndex
      atScrollPosition:UICollectionViewScrollPositionCenteredVertically
      animated:NO];

    DDLogVerbose(@"collectionView didSelectItemAtIndexPath");
    TRUNUSED CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();

    ALAsset *asset = [_photoList objectAtIndex:indexPath.row];
    ALAssetRepresentation *assetRepresentation = [asset defaultRepresentation];

    id<TRImageProvider> provider = [[TRAssetLibraryImageProvider alloc] initWithAssetURL:assetRepresentation.url];
    [self.dataController setImageProvider:provider];

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.popoverDelegate refresh];
        [self.popoverDelegate dismissOpenPopover];
    } else {
        [self performSegueWithIdentifier:@"showEditorGrid" sender:self];
    }

    TRUNUSED CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    DDLogInfo(@"collectionView didSelectItemAtIndexPath took %.3f", end - start);
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldHighlightItemAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)collectionView:(UICollectionView *)colView didHighlightItemAtIndexPath:(NSIndexPath *)indexPath {
    ChooseImageCell* cell = (ChooseImageCell *)[colView cellForItemAtIndexPath:indexPath];
    [cell.imageView setAlpha:0.5];
}

- (void)collectionView:(UICollectionView *)colView didUnhighlightItemAtIndexPath:(NSIndexPath *)indexPath {
    ChooseImageCell* cell = (ChooseImageCell *)[colView cellForItemAtIndexPath:indexPath];
    [cell.imageView setAlpha:1.0];
}

@end
