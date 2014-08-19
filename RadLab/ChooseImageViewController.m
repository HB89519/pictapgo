//
//  ChooseImageViewController.m
//  RadLab
//
//  Created by Geoff Scott on 10/29/12.
//  Copyright (c) 2012 Totally Rad. All rights reserved.
//

#import "ChooseImageViewController.h"
#import "AlbumContentViewController.h"
#import "ShareViewController.h"
#import "AppSettings.h"
#import "MemoryStatistics.h"
#import <AVFoundation/AVMetadataFormat.h>
#import "ChooseImageCell.h"
#import "ChooseImageFooter.h"
#import "EditGridViewController.h"
#import <MobileCoreServices/UTCoreTypes.h>
#import "PTGNotify.h"
#import "TRImageProvider.h"
#import "TRStatistics.h"
#import "UICommon.h"

static int ddLogLevel = LOG_LEVEL_INFO;
typedef enum { kAlertNoPermission, kAlertExplainPermission } InternalDialog;
typedef enum { kViewAllPhotos, kViewAlbums } ViewAllOrAlbums;

@interface ChooseImageViewController () <UICollectionViewDataSource,
                                        UITableViewDataSource,
                                        UITableViewDelegate,
                                        UIActionSheetDelegate,
                                        UIAlertViewDelegate>
{
    int _viewLoadCount;
    NSIndexPath* _scrollIndex;
    NSArray* _groupList;
    NSArray* _photoList;
    NSConditionLock* _fillListsLock;
    BOOL _photoListIsFilled;
    BOOL _groupListIsFilled;
    ViewAllOrAlbums _viewAllOrAlbums;
}

@property (nonatomic, retain) CameraOverlayViewController *cameraOverlayViewController;
@property (atomic) BOOL reloadAssets;
@property (atomic) BOOL reloadAssetsAgain;
@property (strong) ALAssetsLibrary* assetsLibrary;
@property (nonatomic, retain) CLLocationManager* locationManager;
@end

NSString *kImageCellID = @"imageGridID";
NSString *kImageHeaderID = @"imageGridHeader";
NSString *kImageFooterID = @"imageGridFooter";
NSString *kAlbumCellID = @"albumCellID";

@implementation ChooseImageViewController

@synthesize dataController = _dataController;
@synthesize popoverDelegate = _popoverDelegate;
@synthesize cameraOverlayViewController = _cameraOverlayViewController;
@synthesize tableView = _tableView;
@synthesize gridView = _gridView;
@synthesize editButton = _editButton;
@synthesize toolBar = _toolBar;
@synthesize navImageBack = _navImageBack;
@synthesize toolImageBack = _toolImageBack;
@synthesize albumsButton = _albumsButton;
@synthesize assetsLibrary = _assetsLibrary;
@synthesize locationManager = _locationManager;

enum AssetListLoadingCondition {COND_READY, COND_RUNNING, COND_CAMERA};

- (void)dealloc {
    DDLogInfo(@"ChooseImageViewController dealloc; view %d", self.isViewLoaded);

    _groupList = nil;
    _photoList = nil;
    _scrollIndex = nil;
    _fillListsLock = nil;

    _cameraOverlayViewController = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)firstTimeInitialization {
    // Some stuff that is saved between occurrences of loading the view
    _viewAllOrAlbums = kViewAllPhotos;
    _scrollIndex = nil;
    _fillListsLock = [[NSConditionLock alloc] initWithCondition:COND_READY];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    if (_viewLoadCount++ == 0)
        [self firstTimeInitialization];

    _groupList = [[NSArray alloc] init];
    _photoList = [[NSArray alloc] init];
    self.reloadAssets = YES;

    [self.gridView registerNib:[UINib nibWithNibName:@"Cell_ChooseGridView" bundle:[NSBundle mainBundle]] forCellWithReuseIdentifier:kImageCellID];
    [self.gridView registerNib:[UINib nibWithNibName:@"Header_ChooseGridView" bundle:[NSBundle mainBundle]] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:kImageHeaderID];
    [self.gridView registerNib:[UINib nibWithNibName:@"Footer_ChooseGridView" bundle:[NSBundle mainBundle]] forSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:kImageFooterID];
    [self.tableView registerNib:[UINib nibWithNibName:@"Cell_ChooseTableView" bundle:[NSBundle mainBundle]] forCellReuseIdentifier:kAlbumCellID];

    self.assetsLibrary = [[ALAssetsLibrary alloc] init];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(assetsLibraryChanged:)
                                                 name:ALAssetsLibraryChangedNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillEnterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    
    if (_viewAllOrAlbums == kViewAlbums)
        [self chooseAlbums:nil];

}

- (BOOL)pasteboardContainsImage {
    UIPasteboard* pb = [UIPasteboard generalPasteboard];
    return [pb containsPasteboardTypes:[NSArray arrayWithObjects:
      (NSString *)kUTTypeJPEG, (NSString *)kUTTypePNG, nil]];
}

void setEnabled(UIButton* btn, BOOL enable) {
    [btn setEnabled:enable];
    [btn setAlpha:(enable ? 1.0 : 0.5)];
}

- (void)enableOrDisableButtons {
    setEnabled(self.editButton, [self.dataController hasMaster]);
    BOOL pbEnabled = self.pasteboardContainsImage;
    [self.pasteButton setEnabled:pbEnabled];
    [self.pasteButton setSelected:pbEnabled];
}

BOOL assetLibraryAuthorized(ALAuthorizationStatus status) {
    return (status == ALAuthorizationStatusAuthorized ||
      status == ALAuthorizationStatusNotDetermined);
}

- (void)confirmAssetLibraryAuthorization {
    PermissionsCheck chk = [AppSettings manager].permissionsCheck;
    if (chk == kPermissionsQuitBuggingMe || assetLibraryAuthorized([ALAssetsLibrary authorizationStatus]))
        return;
    UIActionSheet* alert = [[UIActionSheet alloc]
      initWithTitle:@"PicTapGo does not have permission\nto access your image library"
      delegate:self cancelButtonTitle:@"Quit bugging me"
      destructiveButtonTitle:nil otherButtonTitles:@"Tell me how to fix it", nil];
    alert.tag = kAlertNoPermission;
    [alert showInView:self.view];
}

- (void)viewDidAppear:(BOOL)animated {
    NSAssert(self.dataController, @"ChooseImageViewController appeared without dataController");
    [super viewDidAppear:animated];

    [self confirmAssetLibraryAuthorization];

    if (! AppSettings.manager.visitedPicScreen) {
        [self.popoverDelegate dismissOpenPopover];
        [PTGNotify displayInitialHelp:@"Help_Pic"
                       withAlertTitle:NSLocalizedString(@"WELCOME", nil)
                           pageNumber:1
                     ofTotalPageCount:4
                      withButtonTitle:NSLocalizedString(@"I'm ready!", nil)
                  aboveViewController:self
                  withCompletionBlock:^(void){[self.popoverDelegate reopenLastPopover];}];
    }
    [self reloadAssetsLibrary];

    self.locationManager = [[CLLocationManager alloc] init];
    if (self.locationManager) {
        [self.locationManager startUpdatingLocation];
        if ([CLLocationManager headingAvailable])
            [self.locationManager startUpdatingHeading];
    }

    addMaskToToolBar(self.toolBar);
    
    if (AppSettings.manager.useSimpleBackground) {
        [self.navImageBack setAlpha:1.0];
        [self.toolImageBack setAlpha:1.0];
    } else {
        [self.navImageBack setAlpha:0.65];
        [self.toolImageBack setAlpha:0.65];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    AppSettings.manager.visitedPicScreen = YES;
    [super viewWillDisappear:animated];
}

- (void)my_viewWillUnload {
    DDLogInfo(@"begin will unload Choose view (mem %@) sections=%zd", stringWithMemoryInfo(), [self.gridView numberOfSections]);
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    _cameraOverlayViewController = nil;
    _photoList = nil;
    _groupList = nil;
    _photoListIsFilled = NO;
    _groupListIsFilled = NO;
    _assetsLibrary = nil;

    //[ALAssetsLibrary purgeSingleton];
    DDLogInfo(@"finished will unload Choose view (mem %@)", stringWithMemoryInfo());
}

- (void)my_viewDidUnload {
    DDLogError(@"did unload Choose view %d", self.isViewLoaded);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    if (self.isViewLoaded && self.view.window == nil &&
      self.cameraOverlayViewController == nil) {
        DDLogInfo(@"begin Choose didReceiveMemoryWarning (mem %@)", stringWithMemoryInfo());
        [self.popoverDelegate dismissOpenPopover];
        [self my_viewWillUnload];
        self.view = nil;
        [self my_viewDidUnload];
        DDLogInfo(@"finished Choose didReceiveMemoryWarning (mem %@)", stringWithMemoryInfo());
    } else {
        //[self.dataController releaseMemoryForAllButChooseView:self];
    }
}

- (void)reloadAssetsLibrary {
    DDLogInfo(@"ChooseImageViewController reloadAssetsLibrary");
    self.reloadAssets = YES;
    [self startFillingAssetLists];
    [self enableOrDisableButtons];
}

- (void)assetsLibraryChanged:(NSNotification*)notification {
    DDLogInfo(@"ChooseImageViewController assetsLibraryChanged");
    self.reloadAssets = YES;
    // If we're currently on-screen, update the grid
    if (self.isViewLoaded && self.view.window != nil &&
      self.cameraOverlayViewController == nil) {
        [self reloadAssetsLibrary];
    }
}

- (void)applicationWillEnterForeground:(NSNotification*)notification {
    DDLogInfo(@"ChooseImageViewController applicationWillEnterForeground (mem %@)", stringWithMemoryInfo());

    if (self.isViewLoaded && self.view.window != nil &&
      self.cameraOverlayViewController == nil) {
        // Force reloading all assets.  Might happen twice, once for entering
        // foreground and once again for the library changed event.  This is surely
        // overkill, but better to have a consistent view of assets at the expense
        // of a pretty-much user-invisible grid refresh.
        [self reloadAssetsLibrary];
    }
}

- (void)makeUICurrentWithLists {
    DDLogInfo(@"makeUICurrentWithLists now reloading lists");
    NSAssert([NSThread isMainThread], @"makeUICurrentWithLists not on main thread");

    [self.gridView reloadData];
    [self.tableView reloadData];

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

- (void)startFillingAssetLists {
    if (!self.reloadAssets) {
        DDLogInfo(@"assets haven't changed");
        return;
    }

    DDLogVerbose(@"startFillingAssetLists fillListsLock %zd", _fillListsLock.condition);
    if (![_fillListsLock tryLockWhenCondition:COND_READY] &&
      ![_fillListsLock tryLockWhenCondition:COND_CAMERA]) {
        DDLogInfo(@"assets list fill operation already running");
        self.reloadAssetsAgain = YES;
        return;
    }

    _photoListIsFilled = NO;
    _groupListIsFilled = NO;
    [_fillListsLock unlockWithCondition:COND_RUNNING];
    DDLogVerbose(@"startFillingAssetLists fillListsLock now %zd", _fillListsLock.condition);
    
    [self fillAvailablePhotoList];
    [self fillAvailableGroupList];
}

- (void) doneFillingAssetLists {
    DDLogVerbose(@"doneFillingAssetLists fillListsLock %zd", _fillListsLock.condition);
    [_fillListsLock lockWhenCondition:COND_RUNNING];
    [_fillListsLock unlockWithCondition:COND_READY];
    DDLogVerbose(@"doneFillingAssetLists fillListsLock now %zd", _fillListsLock.condition);
    self.reloadAssets = NO;
    [self makeUICurrentWithLists];
    if (self.reloadAssetsAgain) {
        DDLogWarn(@"doneFillingAssetLists reloadAssetsAgain!!!");
        self.reloadAssetsAgain = NO;
        [self reloadAssetsLibrary];
    }
}

- (void)doneFillingPhotoList:(NSArray*)unsortedPhotoList {
    @autoreleasepool {
        NSArray* sortedList = [unsortedPhotoList sortedArrayUsingComparator:^NSComparisonResult(ALAsset* obj1, ALAsset* obj2){
            NSDate *photoDate1;
            NSDate *photoDate2;
            [[[obj1 defaultRepresentation] url]
              getResourceValue:&photoDate1 forKey:NSURLContentModificationDateKey
              error:nil];
            [[[obj2 defaultRepresentation] url]
              getResourceValue:&photoDate2 forKey:NSURLContentModificationDateKey
              error:nil];
            return [photoDate1 compare:photoDate2];
        }];

        BOOL allDone = NO;
        DDLogVerbose(@"doneFillingPhotoList fillListsLock %zd", _fillListsLock.condition);
        [_fillListsLock lockWhenCondition:COND_RUNNING];
        _photoListIsFilled = true;
        _photoList = sortedList;
        if (_groupListIsFilled)
            allDone = YES;
        [_fillListsLock unlockWithCondition:COND_RUNNING];
        DDLogVerbose(@"doneFillingPhotoList fillListsLock now %zd", _fillListsLock.condition);
        if (allDone)
            [self doneFillingAssetLists];
    }
}

- (void)doneFillingGroupList:(NSArray*)unsortedGroupList {
    @autoreleasepool {
        NSArray* sortedList = [unsortedGroupList sortedArrayUsingComparator:^NSComparisonResult(ALAsset* obj1, ALAsset* obj2){
            NSString *groupName1 = [obj1 valueForProperty:ALAssetsGroupPropertyName];
            NSString *groupName2 = [obj2 valueForProperty:ALAssetsGroupPropertyName];
            
            if ([groupName1 isEqualToString:NSLocalizedString(@"Camera Roll", nil)]) {
                return NSOrderedAscending;
            } else if ([groupName2 isEqualToString:NSLocalizedString(@"Camera Roll", nil)]) {
                return NSOrderedDescending;
            } else if ([groupName1 isEqualToString:NSLocalizedString(@"Photo Library", nil)]) {
                return NSOrderedAscending;
            } else if ([groupName2 isEqualToString:NSLocalizedString(@"Photo Library", nil)]) {
                return NSOrderedDescending;
            } else if ([groupName1 isEqualToString:NSLocalizedString(@"My Photo Stream", nil)]) {
                return NSOrderedAscending;
            } else if ([groupName2 isEqualToString:NSLocalizedString(@"My Photo Stream", nil)]) {
                return NSOrderedDescending;
           } else {
                return [groupName1 localizedCaseInsensitiveCompare:groupName2];
            }
            return NSOrderedSame;
        }];

        BOOL allDone = NO;
        DDLogVerbose(@"doneFillingGroupList fillListsLock %zd", _fillListsLock.condition);
        [_fillListsLock lockWhenCondition:COND_RUNNING];
        _groupListIsFilled = true;
        _groupList = sortedList;
        if (_photoListIsFilled)
            allDone = YES;
        [_fillListsLock unlockWithCondition:COND_RUNNING];
        DDLogVerbose(@"doneFillingGroupList fillListsLock now %zd", _fillListsLock.condition);
        if (allDone)
            [self doneFillingAssetLists];
    }
}

- (void) fillAvailablePhotoList {
    _photoList = nil;

    __block ChooseImageViewController* mySelf = self;
    __block NSMutableArray* pList = [[NSMutableArray alloc] init];
    ALAssetsLibraryGroupsEnumerationResultsBlock listGroupBlock = ^(ALAssetsGroup *group, BOOL *stop) {
        @autoreleasepool {
            // always ends with call of a null group, so reload data then
            if (group) {
                [group setAssetsFilter:[ALAssetsFilter allPhotos]];
                [group enumerateAssetsUsingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {
                    if (result)
                        [pList addObject:result];
                }];
            } else {
                [mySelf performSelectorOnMainThread:@selector(doneFillingPhotoList:) withObject:pList waitUntilDone:YES];
                mySelf = nil;
                pList = nil;
            }
        }
    };
    
    ALAssetsLibraryAccessFailureBlock failureBlock = ^(NSError *error) {
        DDLogError(@"Problem accessing the assets library");
        mySelf = nil;
    };
    
    // photo stream images are not show in the big list because of duplicates
    //    NSUInteger groupTypes = ALAssetsGroupLibrary | ALAssetsGroupSavedPhotos | ALAssetsGroupPhotoStream;
    NSUInteger groupTypes = ALAssetsGroupLibrary | ALAssetsGroupSavedPhotos;
    [self.assetsLibrary enumerateGroupsWithTypes:groupTypes usingBlock:listGroupBlock failureBlock:failureBlock];
}

- (void) fillAvailableGroupList {
    _groupList = nil;

    __block ChooseImageViewController* mySelf = self;
    __block NSMutableArray* gList = [[NSMutableArray alloc] init];
    ALAssetsLibraryGroupsEnumerationResultsBlock listGroupBlock = ^(ALAssetsGroup *group, BOOL *stop) {
        @autoreleasepool {
            if (group) {
                [gList addObject:group];
            } else {
                [mySelf performSelectorOnMainThread:@selector(doneFillingGroupList:) withObject:gList waitUntilDone:YES];
                mySelf = nil;
                gList = nil;
            }
        }
    };
    
    ALAssetsLibraryAccessFailureBlock failureBlock = ^(NSError *error) {
        DDLogError(@"Problem accessing the assets library");
        mySelf = nil;
    };
    
    NSUInteger groupTypes = ALAssetsGroupSavedPhotos | ALAssetsGroupAlbum | ALAssetsGroupLibrary | ALAssetsGroupPhotoStream;
    [self.assetsLibrary enumerateGroupsWithTypes:groupTypes usingBlock:listGroupBlock failureBlock:failureBlock];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    DDLogInfo(@"ChooseImageViewController prepareForSegue %@", segue.identifier);
    if ([[segue identifier] isEqualToString:@"showEditorGrid"]) {
        EditGridViewController *editController = (EditGridViewController *)[segue destinationViewController];
        [editController setDataController:self.dataController];
    } else if ([[segue identifier] isEqualToString:@"showAlbumContents"]) {
        AlbumContentViewController *albumController = (AlbumContentViewController *)[segue destinationViewController];
        [albumController setDataController:self.dataController];
        [albumController setAssetsGroup:[_groupList objectAtIndex:[self.tableView indexPathForSelectedRow].row]];
    } else if ([[segue identifier] isEqualToString:@"showAbout"]) {
        AboutViewController *aboutController = (AboutViewController *)[segue destinationViewController];
        aboutController.navigation = [sender isKindOfClass:[AboutViewNavigation class]] ? sender : nil;
        [aboutController setDelegate:self];
        [aboutController setDataController:self.dataController];
    } else if ([[segue identifier] isEqual:@"showShare"]) {
        ShareViewController* shareController = [segue destinationViewController];
        [shareController setDataController:self.dataController];
    }
}

- (IBAction)showCamera:(id)sender {
    [TRStatistics checkpoint:TRCheckpointUsedCamera];
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        self.cameraOverlayViewController = [[CameraOverlayViewController alloc] initWithNibName:@"CameraOverlayView" bundle:nil];
        self.cameraOverlayViewController.delegate = self;
    
        self.cameraOverlayViewController.imagePickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
        [self.cameraOverlayViewController setupCamera:NO allowsEditing:NO locationManager:self.locationManager];
        
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            // iPad version presents from a popover, which causes layout issues, so present from the delegate instead
            [self.popoverDelegate dismissOpenPopover];
            [self.popoverDelegate presentViewController:self.cameraOverlayViewController.imagePickerController animated:YES completion:nil];
        } else {
            [self presentViewController:self.cameraOverlayViewController.imagePickerController animated:YES completion:nil];
        }
    } else {
        DDLogError(@"No camera available on this device!!");
    }
}

- (IBAction)pasteImage:(id)sender {
    [TRStatistics checkpoint:TRCheckpointUsedPasteboard];
    UIPasteboard* pb = [UIPasteboard generalPasteboard];
    NSData* data = [pb dataForPasteboardType:(NSString *)kUTTypeJPEG];
    if (!data)
        data = [pb dataForPasteboardType:(NSString *)kUTTypePNG];
    if (data) {
        id<TRImageProvider> provider =
          [[TREncodedImageProvider alloc] initWithData:data];
        if (provider) {
            [self.dataController setImageProvider:provider];
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                [self.popoverDelegate refresh];
                [self.popoverDelegate dismissOpenPopover];
            } else {
                [self performSegueWithIdentifier:@"showEditorGrid" sender:nil];
            }
        }
    }
}

- (IBAction)chooseAlbums:(id)sender {
    [TRStatistics checkpoint:TRCheckpointUsedAlbumView];
    
    if (_viewAllOrAlbums == kViewAlbums) {
        _viewAllOrAlbums = kViewAllPhotos;
        [self.gridView setHidden:NO];
        [self.tableView setHidden:YES];
        [self.albumsButton setSelected:NO];
    } else {
        _viewAllOrAlbums = kViewAlbums;
        [self.gridView setHidden:YES];
        [self.tableView setHidden:NO];
        [self.albumsButton setSelected:YES];
    }
}

- (IBAction)doBack:(id)sender {
    @autoreleasepool {
        UINavigationController *navCon = [self navigationController];
        [navCon popViewControllerAnimated:YES];
    }
}

#pragma mark - AboutViewControllerDelegate

- (void)doCloseAboutView:(AboutViewController *)controller {
    [self dismissViewControllerAnimated:YES completion:NULL];    
}

#pragma mark - CameraOverlayViewControllerDelegate

- (void)didTakePicture:(UIImage *)picture metadata:(NSDictionary*)metadata {
    DDLogInfo(@"didTakePicture fillListsLock %zd", _fillListsLock.condition);
    if ([_fillListsLock tryLockWhenCondition:COND_READY])
        [_fillListsLock unlockWithCondition:COND_CAMERA];
    DDLogInfo(@"didTakePicture fillListsLock now %zd", _fillListsLock.condition);
    id<TRImageProvider> provider = [[TRCameraImageProvider alloc] initWithCameraImage:picture metadata:metadata];
    [self.dataController setImageProvider:provider];

    [self dismissViewControllerAnimated:YES completion:NULL];
    self.cameraOverlayViewController = nil;

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.popoverDelegate refresh];
        [self.popoverDelegate dismissViewControllerAnimated:YES completion:NULL];
    } else {
        [self performSegueWithIdentifier:@"showEditorGrid" sender:nil];
    }
}

- (void)didCancelCamera {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.popoverDelegate dismissViewControllerAnimated:YES completion:NULL];
    } else {
        [self dismissViewControllerAnimated:YES completion:NULL];
    }
    self.cameraOverlayViewController = nil;
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)view numberOfItemsInSection:(NSInteger)section; {
    return [_photoList count];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)indexPath; {
    ChooseImageCell *cell = [cv dequeueReusableCellWithReuseIdentifier:kImageCellID forIndexPath:indexPath];

    @autoreleasepool {
        ALAsset *asset = [_photoList objectAtIndex:indexPath.row];
        CGImageRef thumbnailImageRef = [asset thumbnail];
        UIImage *thumbnail = [UIImage imageWithCGImage:thumbnailImageRef];
        [cell setImage:thumbnail];
    }

    return cell;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    DDLogVerbose(@"CHOOSE viewForSupplementaryElementOfKind %@ at path %@ (lists %d %d)", kind, indexPath, _photoListIsFilled, _groupListIsFilled);

    UICollectionReusableView *retview = nil;
    if (kind == UICollectionElementKindSectionFooter) {
        ChooseImageFooter *footer = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:kImageFooterID forIndexPath:indexPath];
        if (_photoListIsFilled || _groupListIsFilled) {
            NSInteger count = _photoList.count;
            [footer.imageCountLabel setText:(count == 1 ? NSLocalizedString(@"1 Photo", nil) : [NSString stringWithFormat:NSLocalizedString(@"%d Photos", nil), count])];
        }
        retview = footer;
    } else if (kind == UICollectionElementKindSectionHeader) {
        retview = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:kImageHeaderID forIndexPath:indexPath];
    }
    
    return retview;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    _scrollIndex = indexPath;
    [self.gridView deselectItemAtIndexPath:indexPath animated:NO];

    DDLogInfo(@"collectionView didSelectItemAtIndexPath");
    TRUNUSED CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    ALAsset *asset = [_photoList objectAtIndex:indexPath.row];
    ALAssetRepresentation *assetRepresentation = [asset defaultRepresentation];

    id<TRImageProvider> provider = [[TRAssetLibraryImageProvider alloc] initWithAssetURL:assetRepresentation.url];
    [self.dataController setImageProvider:provider];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.popoverDelegate refresh];
        [self.popoverDelegate dismissOpenPopover];
    } else {
        [self performSegueWithIdentifier:@"showEditorGrid" sender:nil];
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

- (void)collectionView:(UICollectionView*)collectionView didEndDisplayingCell:(UICollectionViewCell*)cell
  forItemAtIndexPath:(NSIndexPath*)indexPath {
    DDLogVerbose(@"didEndDisplayingCell at indexPath %@", indexPath);
}

- (void)collectionView:(UICollectionView*)collectionView didEndDisplayingSupplementaryView:(UICollectionReusableView*)view
  forElementOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath*)indexPath {
    DDLogVerbose(@"didEndDisplayingSupplementaryView of kind %@ at indexPath %@", elementKind, indexPath);
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section {
    return CGSizeMake(320, 48);
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout referenceSizeForFooterInSection:(NSInteger)section {
    CGSize retSize = CGSizeMake(320, 90);
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        retSize = CGSizeMake(320, 40);
    }
    return retSize;
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_groupList count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    @autoreleasepool {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kAlbumCellID forIndexPath:indexPath];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kAlbumCellID];
        }
        
        ALAssetsGroup *groupForCell = [_groupList objectAtIndex:indexPath.row];
        
        CGImageRef posterImageRef = [groupForCell posterImage];
        UIImage *posterImage = [UIImage imageWithCGImage:posterImageRef];
        cell.imageView.image = posterImage;
        
        NSString *albumName = [groupForCell valueForProperty:ALAssetsGroupPropertyName];
        cell.textLabel.text = albumName;
        
        cell.textLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        cell.detailTextLabel.text = [NSString stringWithFormat:@"(%zd)", [groupForCell numberOfAssets]];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
        return cell;
    }
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_groupList.count > indexPath.row) {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            AlbumContentViewController *albumController = [[AlbumContentViewController alloc] initWithNibName:@"Popover_Album" bundle:nil];
            [albumController setDataController:self.dataController];
            [albumController setPopoverDelegate:self.popoverDelegate];
            [albumController setAssetsGroup:[_groupList objectAtIndex:[self.tableView indexPathForSelectedRow].row]];
            
            UINavigationController *navCon = [self navigationController];
            [navCon pushViewController:albumController animated:YES];
        } else {
            [self performSegueWithIdentifier:@"showAlbumContents" sender:self];
        }
    }
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet*)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (actionSheet.tag == kAlertNoPermission) {
        if (buttonIndex == actionSheet.cancelButtonIndex) {
            [AppSettings manager].permissionsCheck = kPermissionsQuitBuggingMe;
            [AppSettings synchronize];
        } else if (buttonIndex == actionSheet.firstOtherButtonIndex) {            
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                [self.popoverDelegate showHelpScreen:@"faq.html#permissions"];
            } else {
                [self performSegueWithIdentifier:@"showAbout" sender:[AboutViewNavigation newHelpURL:@"faq.html#permissions"]];
            }
        }
    }
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == kAlertExplainPermission) {
        [AppSettings manager].permissionsCheck = kPermissionsOK;
        [AppSettings synchronize];
    }
}

@end
