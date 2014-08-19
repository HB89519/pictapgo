//
//  ImageDataController.m
//  RadLab
//
//  Created by Geoff Scott on 10/29/12.
//  Copyright (c) 2012 Totally Rad. All rights reserved.
//

#import "ImageDataController.h"
#import "AppliedRecipeStep.h"
#import "EditGridViewController.h"
#import "TRRecipe.h"
#import "TRStatistics.h"
#import "TRHelper.h"
#import "Scaling.h"
#import "UIImage+Resize.h"
#import "UIDevice-Hardware.h"
#import "MemoryStatistics.h"
#import "MKStoreManager.h"

static int ddLogLevel = LOG_LEVEL_INFO;

@interface ThumbnailAttributes ()
@property (readwrite, strong) NSString* code;
@property (readwrite, strong) NSString* namedRecipeName;
@property (readwrite, strong) NSString* name;
@property (readwrite) ThumbnailCellType type;
@property (readwrite) NSInteger strength;
@property (readwrite) BOOL isLocked;
@end

@implementation ThumbnailAttributes
- (ThumbnailAttributes*) initWithCode:(NSString*)code {
    self = [super init];
    if (self) {
        self.code = code;
        self.name = NSLocalizedString([TRRecipe nameForRecipeCode:code], nil);
        self.namedRecipeName = [TRStatistics nameForCode:code includeHistory:NO];
        LockedRecipeCodeType lockedType = [TRStatistics isRecipeCodeLocked:code];

        self.isLocked = YES;
        switch (lockedType) {
        case LockedRecipeCodeNotLocked:
            self.type = [TRRecipe isBuiltin:code] ? kStyletCellType : kRecipeCellType;
            self.isLocked = NO;
            break;
        case LockedRecipeCodeFacebook:
            self.type = kLockedFacebookCellType;
            break;
        case LockedRecipeCodeInstagram:
            self.type = kLockedInstagramCellType;
            break;
        case LockedRecipeCodeTwitter:
            self.type = kLockedTwitterCellType;
            break;
        case LockedRecipeCodeMailingList:
            self.type = kLockedMailingListCellType;
            break;
        }

        self.strength = 100;
    }
    return self;
}
- (NSURL*)codeURL {
    NSString* name = self.namedRecipeName;
    if (!name || [name isEqual:@""])
        name = @"«Unnamed Recipe»";
    return [TRStatistics urlWithRecipeCode:self.code named:name];
}
@end

@interface LargeImageRunner : NSOperation {
    CGSize size;
    UIImage* result;
    UIImageCompletionBlock imageCompletionBlock;
    NSConditionLock* state;
    ImageDataController* parent;
}
- (void)setImageCompletionBlock:(UIImageCompletionBlock)block;
- (LargeImageRunner*)initWithParent:(ImageDataController*)parent size:(CGSize)size;
@end

// ----------------------------------------------------------------------

@interface ImageDataController () {
    NSMutableArray* styletLibrary;
    NSArray* userRecipeList;
    NSArray* magicList;
    NSArray* historyList;
    NSArray* allRecipesInAllFolders;
    id<TRImageProvider> _imageProvider;
    CGSize deviceMaximumSize;
    CGFloat largeMaximumArea;
    CGSize largeSize;
    CGSize previewSize;
    CGSize thumbnailSize;
    CGSize scaledPreviewPresentationSize;
    CGSize scaledThumbnailPresentationSize;
    NSOperation* _masterPreviewJob;
    NSOperation* _masterThumbJob;
    LargeImageRunner* _currentLargeJob;
    NSOperationQueue* queue;
    NSMutableSet* sharedTo;
    BOOL currentlyHandlingCrash;
    UIImage* crashPreview;
    UIImage* savedCurrentPreview;
    BOOL _isSetup;
    NSTimer* selfTestTimer;
}

@property (strong, atomic) NSMutableArray* appliedStepsList;
@property (nonatomic, readwrite) UIImage* currentLarge;
@end

NSString *kStyletOrderFileName = @"stylet_order.dat";

@implementation ImageDataController

@synthesize masterPreview = _masterPreview;
@synthesize masterThumb = _masterThumb;
@synthesize currentLarge = _currentLarge;
@synthesize currentStepIndex = _currentStepIndex;
@synthesize thumbnailCache = _thumbnailCache;
@synthesize previewCache = _previewCache;
@synthesize cropImageOrientation = _cropImageOrientation;
@synthesize cropSourceImageSize = _cropSourceImageSize;
@synthesize cropTransform = _cropTransform;
@synthesize cropAspectRatio = _cropAspectRatio;
@synthesize hasEmptyMaster = _hasEmptyMaster;

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    styletLibrary = nil;
    userRecipeList = nil;
    magicList = nil;
    historyList = nil;
    allRecipesInAllFolders = nil;
    _imageProvider = nil;
    self.appliedStepsList = nil;
    _masterPreviewJob = nil;
    _masterThumbJob = nil;
    _currentLargeJob = nil;
    queue = nil;
    sharedTo = nil;
    crashPreview = nil;
    savedCurrentPreview = nil;
    _currentStepIndex = nil;
    _thumbnailCache = nil;
    _previewCache = nil;
}

+ (CGFloat) getMaximumCameraImageArea {
    // It would be better to use actual data from the device about how much
    // memory it has and what size CoreImage resolution it can handle, but
    // those are off-limits to Apps that Apple will approve in the App Store.

    UIDevicePlatform platform = [[UIDevice currentDevice] platformType];
    static const CGFloat MP = 1024 * 1024;

    switch (platform) {
    case UIDevice1GiPhone:  return 2.0 * MP;
    case UIDevice3GiPhone:  return 2.0 * MP;
    case UIDevice3GSiPhone: return 3.2 * MP;
    case UIDevice4iPhone:   return 5.0 * MP;
    case UIDevice4SiPhone:  return 8.0 * MP;
    case UIDevice5iPhone:   return 12.0 * MP;

    case UIDevice1GiPod:    return 2.0 * MP;
    case UIDevice2GiPod:    return 2.0 * MP;
    case UIDevice4GiPod:    return 2.0 * MP;
    case UIDevice5GiPod:    return 5.0 * MP;

    case UIDevice1GiPad:    return 2.0 * MP;
    case UIDevice2GiPad:    return 8.0 * MP;
    case UIDevice3GiPad:    return 12.0 * MP;
    case UIDevice4GiPad:    return 12.0 * MP;

    default:                ; // fall through
    }

    UIDeviceFamily family = [[UIDevice currentDevice] deviceFamily];
    switch (family) {
    case UIDeviceFamilyiPhone:  return 12.0 * MP;
    case UIDeviceFamilyiPod:    return 5.0 * MP;
    case UIDeviceFamilyiPad:    return 12.0 * MP;
    default:                    return 8.0 * MP;
    }
}

- (id)init {
    if (self = [super init]) {
        @autoreleasepool {
            [[NSNotificationCenter defaultCenter] addObserver:self
              selector:@selector(applicationWillEnterForeground:)
              name:UIApplicationWillEnterForegroundNotification
              object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:self
              selector:@selector(applicationDidEnterBackground:)
              name:UIApplicationDidEnterBackgroundNotification
              object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:self
              selector:@selector(applicationWillTerminate:)
              name:UIApplicationWillTerminateNotification
              object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:self
              selector:@selector(thumbnailCodeRendered:)
              name:kNotificationThumbnailCodeRendered
              object:nil];

            [self updateCanonicalStyletListIfNecessary];

            CIContext* ctx = [TRHelper getCIContext];
            CGSize iSz = [ctx inputImageMaximumSize], oSz = [ctx outputImageMaximumSize];
            deviceMaximumSize = CGSizeMake(MIN(iSz.width, oSz.width),
              MIN(iSz.height, oSz.height));
            [TRHelper doneWithCIContext:ctx];
            ctx = nil;

            largeMaximumArea = [ImageDataController getMaximumCameraImageArea];

            DDLogError(@"device maximum image sizes for input:%.fx%.f output:%.fx%.f (restricting to %.1fMP)",
              iSz.width, iSz.height, oSz.width, oSz.height, largeMaximumArea / (1024 * 1024));

            [self setPreviewPresentationSize:[EditGridViewController previewSize]];
            [self setThumbnailPresentationSize:[EditGridViewController thumbnailSize]];

            queue = [[NSOperationQueue alloc] init];
            queue.maxConcurrentOperationCount = 1;
            sharedTo = [[NSMutableSet alloc] init];
            userRecipeList = [[NSArray alloc] init];
            _thumbnailCache = [[NSCache alloc] init];
            _previewCache = [[NSCache alloc] init];
            [self clearMasterImage];

            [self setupAllRecipesInAllFolders];
        }
        
        _isSetup = NO;
        _hasEmptyMaster = NO;
    }
    
    return self;
}

- (void)applicationWillEnterForeground:(NSNotification*)notification {
    [self loadStyletList];
}

- (void)applicationDidEnterBackground:(NSNotification*)notification {
    [self saveStyletList];
}

- (void)applicationWillTerminate:(NSNotification*)notification {
    [self saveStyletList];
}

- (void)selfTestFired {
    NSAssert(styletLibrary, @"styletLibrary is empty");

    DDLogInfo(@"#######");
    int action = arc4random_uniform(20);
    if (!_imageProvider)
        action = 0;

    if (action == 0) {
        DDLogInfo(@"####### selfTestFired set image provider");
        UIImage *testImage = [UIImage imageNamed:@"Background_GoScroll.png"];
        id<TRImageProvider> provider = [[TRUIImageProvider alloc] initWithUIImage:testImage metadata:nil];
        [self setImageProvider:provider];
    } else if (action == 1) {
        DDLogInfo(@"####### selfTestFired using undo");
        [self undoAppliedStylet];
    } else if (action == 2) {
        DDLogInfo(@"####### selfTestFired using redo");
        [self redoAppliedStylet];
    } else if (action == 3) {
        DDLogInfo(@"####### selfTestFired reset recipe");
        [self resetRecipe];
    } else if (action == 4) {
        DDLogInfo(@"####### selfTestFired purge caches");
        [self purgeCaches];
    } else if (action >= 5 && action <= 7) {
        DDLogInfo(@"####### selfTestFired purge stylet preflight caches");
        [TRRecipe purgeCaches];
    } else if (action <= 12) {
        int whichStylet = arc4random_uniform((uint32_t)styletLibrary.count);
        NSString* code = (NSString*)[styletLibrary objectAtIndex:whichStylet];
        DDLogInfo(@"####### selfTestFired applying code %@", code);
        [self applyStyletWithCode:code];
    } else {
        int strength = arc4random_uniform(101);
        DDLogInfo(@"####### selfTestFired adjusting strength %d", strength);
        [self setCurrentStrength:[NSNumber numberWithInt:strength]];
    }

    NSTimeInterval wait = (0.2 + arc4random_uniform(10) + arc4random_uniform(10) + arc4random_uniform(10)) / 10.0;
    DDLogInfo(@"####### wait %.1f", wait);
    selfTestTimer = [NSTimer scheduledTimerWithTimeInterval:wait target:self selector:@selector(selfTestFired) userInfo:nil repeats:NO];
}

- (void)selfTestReceivedMemoryWarning {
    DDLogInfo(@"###############");
    DDLogInfo(@"####### selfTestReceivedMemoryWarning");
    DDLogInfo(@"###############");
    [self releaseMemoryForEditView];
}

- (void)selfTestReceivedWillResignActive {
    DDLogInfo(@"####### selfTestReceivedResignActive");
    if (selfTestTimer)
        [selfTestTimer invalidate];
}

- (void)selfTestReceivedDidBecomeActive {
    DDLogInfo(@"####### selfTestReceivedDidBecomeActive");
    if (selfTestTimer)
        [self selfTestFired];
}

- (void)selfTest {
    NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(selfTestReceivedMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    [nc addObserver:self selector:@selector(selfTestReceivedWillResignActive) name:UIApplicationWillResignActiveNotification object:nil];
    [nc addObserver:self selector:@selector(selfTestReceivedDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];

    UIImage *testImage = [UIImage imageNamed:@"Background_GoScroll.png"];
    id<TRImageProvider> provider = [[TRUIImageProvider alloc] initWithUIImage:testImage metadata:nil];
    [self setImageProvider:provider];

    selfTestTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(selfTestFired) userInfo:nil repeats:NO];
}

- (void)setupAllRecipesInAllFolders {
    allRecipesInAllFolders = [[NSArray alloc] initWithObjects:
      magicList,
      userRecipeList,
      historyList,
      styletLibrary,
      nil];
}

- (BOOL)isControllerSetup {
    return _isSetup;
}

- (void)resetAllRecipesInAllFolders {
    [self loadStyletList];
    [self loadUserRecipeList];
    [self loadHistoryList];
    [self loadMagicList];
    [self setupAllRecipesInAllFolders];
}

- (void)setupController {
    [self resetAllRecipesInAllFolders];
    [self startImageProviderJobs];
    [self resetRecipe];
    [self resetAppliedTools];
    _isSetup = YES;
}

- (NSString*)savedOrderPath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    return [documentsDirectory stringByAppendingPathComponent:kStyletOrderFileName];
}

- (NSArray*)savedOrderList {
    NSString *savePath = [self savedOrderPath];
    return [NSMutableArray arrayWithContentsOfFile:savePath];
}

- (void)deleteSavedOrderList {
    NSString* savePath = [self savedOrderPath];
    NSError* error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:savePath error:&error];
}

- (void)updateCanonicalStyletListIfNecessary {
    NSArray* savedOrderList = [self savedOrderList];
    if (!savedOrderList)
        return;

    NSString *buildStr = [NSString stringWithFormat:@"%@",
      [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]];
    NSNumberFormatter* f = [[NSNumberFormatter alloc] init];
    f.numberStyle = NSNumberFormatterDecimalStyle;
    NSNumber* buildNum = [f numberFromString:buildStr];

    NSMutableArray* canonicalMatches = [[NSMutableArray alloc] init];
    NSDictionary* libraries = [TRRecipe historicalStyletLibraries];
    for (NSNumber* n in [[libraries allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
        if ([n compare:buildNum] != NSOrderedAscending) {
            // skip any canonical lists >= current version
            continue;
        }
        NSArray* canonical = [libraries objectForKey:n];
        if ([savedOrderList isEqualToArray:canonical])
            [canonicalMatches addObject:n];
    }

    if (canonicalMatches.count > 0) {
        // If we matched some prior canonical list simply delete the order
        // file, which will then be recreated later via loadStyletList
        DDLogWarn(@"NOTICE: stylet order is canonical for builds %@",
          [canonicalMatches componentsJoinedByString:@" "]);
        [self deleteSavedOrderList];
    }
}

- (BOOL)loadStyletList {
    styletLibrary = [[NSMutableArray alloc]
      initWithArray:[TRRecipe styletLibrary] copyItems:YES];

//    if ([MKStoreManager featurePurchased1]) {
//        [styletLibrary addObject:@"Xra"];
//        [styletLibrary addObject:@"Xrb"];
//        [styletLibrary addObject:@"Xrc"];
//        [styletLibrary addObject:@"Xrd"];
//        [styletLibrary addObject:@"Xre"];
//        [styletLibrary addObject:@"Xrf"];
//        [styletLibrary addObject:@"Xrg"];
//        [styletLibrary addObject:@"Xrh"];
//        [styletLibrary addObject:@"Xri"];
//        [styletLibrary addObject:@"Xrj"];
//    }
    
    NSArray* savedOrderList = [self savedOrderList];
    if (!savedOrderList)
        return NO;

    // reorder the styletLibrary list to match the saved list
    for (NSUInteger i = 0; i < [savedOrderList count]; i++) {
        NSString *curIdent = (NSString*)[savedOrderList objectAtIndex:i];
        for (NSUInteger j = i; j < [styletLibrary count]; j++) {
            NSString *curStylet = (NSString*)[styletLibrary objectAtIndex:j];
            if ([curIdent isEqualToString:curStylet]) {
                // found it
                if (j != i) {
                    [styletLibrary exchangeObjectAtIndex:j withObjectAtIndex:i];
                }
                break;
            }
        }
    }

    return YES;
}

- (BOOL)saveStyletList {
    NSString* savePath = [self savedOrderPath];
    return [styletLibrary writeToFile:savePath atomically:YES];
}

- (void)resetStyletList {
    styletLibrary = [[NSMutableArray alloc] initWithArray:[TRRecipe styletLibrary] copyItems:YES];
    [self saveStyletList];
}

- (void)loadUserRecipeList {
    userRecipeList = [TRRecipe namedRecipes];
}

- (void)loadMagicList {
    magicList = [TRStatistics magicListWithLimit:12];
}

- (void)loadHistoryList {
    NSArray* usageHistory = [TRStatistics usageHistoryListWithLimit:3];
    NSMutableArray* a = [[NSMutableArray alloc] init];
    for (NSDictionary* d in usageHistory) {
        [a addObject:[d valueForKey:@"recipe_code"]];
    }
    historyList = a;
}

- (void)clearMasterImage {
    DDLogInfo(@"clearMasterImage");

    [queue cancelAllOperations];
    [queue waitUntilAllOperationsAreFinished];

    @synchronized (self) {
        _imageProvider = nil;
        _masterPreview = nil;
        _masterThumb = nil;
        if (_masterPreviewJob)
            [_masterPreviewJob cancel];
        _masterPreviewJob = nil;
        if (_masterThumbJob)
            [_masterThumbJob cancel];
        _masterThumbJob = nil;
        _currentStepIndex = -1;
        largeSize = CGSizeZero;
        previewSize = CGSizeZero;
        thumbnailSize = CGSizeZero;
        self.appliedStepsList = [[NSMutableArray alloc] init];
    }
}

- (BOOL)hasMaster {
    DDLogInfo(@"hasMaster");
    @synchronized (self) {
        return (_imageProvider != nil);
    }
}

- (void)setEmptyImageProvider {
    UIImage *emptyImage = [UIImage imageNamed:@"EmptyImage.png"];
    id<TRImageProvider> provider = [[TRUIImageProvider alloc] initWithUIImage:emptyImage metadata:nil];
    [self setImageProvider:provider];
    _hasEmptyMaster = YES;
}

- (NSDictionary*)masterMetadata {
    id<TRImageProvider> provider = nil;
    @synchronized (self) {
        provider = _imageProvider;
    }
    return provider.metadata;
}

- (void)cancelEntireRecipe {
    NSArray* steps = self.appliedStepsList;
    if (steps) {
        for (AppliedRecipeStep* s in steps) {
            DDLogInfo(@"cancel step %p", s);
            [s cancel];
            [s releaseMemoryForEditView];
        }
    }
}

- (void)setImageProvider:(id<TRImageProvider>)provider {
    DDLogInfo(@"setImageProvider %@", provider);
    @synchronized (self) {
        _imageProvider = provider;
    }
    [self cancelEntireRecipe];
    [self pruneRedoState];
    [self purgeCaches];
    [self setupController];
    _hasEmptyMaster = NO;
}

- (void)applyTools {
    DDLogInfo(@"applyTools");
    [self purgeCaches];

    id<TRImageProvider> originalProvider = [_imageProvider originalProvider];
    if (!originalProvider)
        originalProvider = _imageProvider;

    id<TRImageProvider> newProvider = [[TRTransformedImageProvider alloc]
      initWithProvider:originalProvider previewSize:scaledPreviewPresentationSize
      referenceImageSize:self.cropSourceImageSize imageOrientation:self.cropImageOrientation
      cropAspect:self.cropAspectRatio cropTransform:self.cropTransform];
    _imageProvider = newProvider;

    [self startImageProviderJobs];
    UIImage* preview = self.masterPreview;
    UIImage* thumb = self.masterThumb;

    NSMutableArray* steps = [NSMutableArray arrayWithArray:self.appliedStepsList];
    for (AppliedRecipeStep* step in steps)
        [step releaseMemoryForEditView];
    [[steps objectAtIndex:0] changePreview:preview thumb:thumb];
    self.appliedStepsList = steps;
}

- (void)purgeCaches {
    [_thumbnailCache removeAllObjects];
    [_previewCache removeAllObjects];

    int step = 0;
    NSArray* steps = self.appliedStepsList;
    for (AppliedRecipeStep* a in steps) {
        if (step != _currentStepIndex)
            [a releaseMemoryForNonVisibleStep];
        ++step;
    }
}

- (void)releaseMemoryForAllButChooseView:(ChooseImageViewController*)controller {
    DDLogInfo(@"releaseMemoryForAllButChooseView");
    self->_imageProvider = nil;
}

- (void)releaseMemoryForEditView {
    DDLogInfo(@"ImageDataController releaseMemoryForEditView");
    savedCurrentPreview = [self currentPreviewAtCurrentStrength];
    NSArray* steps = self.appliedStepsList;
    for (AppliedRecipeStep* s in steps)
        [s releaseMemoryForEditView];
    [self purgeCaches];

    DDLogInfo(@"begin TRRecipe purgeCaches (mem %@)", stringWithMemoryInfo());
    [TRRecipe purgeCaches];
    DDLogInfo(@"finish TRRecipe purgeCaches (mem %@)", stringWithMemoryInfo());
}

- (void)releaseMemoryForShareView:(ShareViewController*)controller {
    DDLogInfo(@"releaseMemoryForShareView");
    [self resetCurrentLarge];
}

- (void)setThumbnailPresentationSize:(CGSize)sz {
    CGFloat scale = [UIScreen mainScreen].scale;
    scaledThumbnailPresentationSize = CGSizeMake(sz.width * scale, sz.height * scale);
}

- (void)setPreviewPresentationSize:(CGSize)sz {
    CGFloat scale = [UIScreen mainScreen].scale;
    scaledPreviewPresentationSize = CGSizeMake(sz.width * scale, sz.height * scale);
}

- (void)renderMasterPreview {
    TRUNUSED CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    DDLogVerbose(@"masterPreviewJob starting %.1fx%.1f",
      previewSize.width, previewSize.height);
    UIImage* image = [self->_imageProvider previewSizeImage];
    NSAssert(image, @"renderMasterPreview imageProvider previewSizeImage returned nil");
    UIImage* preview = [image resizedImage:previewSize
      interpolationQuality:kCGInterpolationMedium];

    NSAssert(preview.imageOrientation == UIImageOrientationUp,
      @"Expected preview image to have UP orientation");

    self->_masterPreview = preview;
    TRUNUSED CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    DDLogInfo(@"masterPreviewJob done (took %.3f) %.1fx%.1f -> %.1fx%.1f",
      end - start, image.size.width, image.size.height,
      preview.size.width, preview.size.height);
}

- (void)renderMasterThumb:(CGSize)thSize {
    TRUNUSED CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    DDLogVerbose(@"masterThumbJob starting %.1fx%1.f",
      thSize.width, thSize.height);
    UIImage* image = self.masterPreview;
    NSAssert(image, @"ImageDataController renderMasterThumb self.masterPreview returned nil");
    UIImage* thumb = [image resizedImage:thSize
      interpolationQuality:kCGInterpolationMedium];
    self->_masterThumb = thumb;
    TRUNUSED CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    DDLogInfo(@"masterThumbJob done (took %.3f) %.1fx%.1f %p", end - start,
      thumb.size.width, thumb.size.height, self->_masterThumb);
}

- (void)startImageProviderJobs {
    CGSize fullSize = [_imageProvider fullDimensions];
    CGSize lgSize = scaleArea(scaleAspectFit(fullSize, deviceMaximumSize), largeMaximumArea);
    CGSize prSize = scaleAspectFit(fullSize, scaledPreviewPresentationSize);
    CGSize thSize = scaleAspectFill(fullSize, scaledThumbnailPresentationSize, false);
    @synchronized (self) {
        largeSize = lgSize;
        previewSize = prSize;
        thumbnailSize = thSize;
    }

    DDLogInfo(@"startImageProviderJobs size=%.1fx%.1f largeSize=%.1fx%.1f",
      fullSize.width, fullSize.height, largeSize.width, largeSize.height);

    [self resetCurrentLarge];

    __block ImageDataController* mySelf1 = self;
    _masterPreviewJob = [NSBlockOperation blockOperationWithBlock:^(void){
        [mySelf1 renderMasterPreview];
    }];
    _masterPreviewJob.completionBlock = ^{
        mySelf1->_masterPreviewJob = nil;
        mySelf1 = nil;
    };
    [_masterPreviewJob setQueuePriority:NSOperationQueuePriorityHigh];
    [queue addOperation:_masterPreviewJob];

    __block ImageDataController* mySelf2 = self;
    _masterThumbJob = [NSBlockOperation blockOperationWithBlock:^(void){
        [mySelf2 renderMasterThumb:thSize];
    }];
    _masterThumbJob.completionBlock = ^{
        mySelf2->_masterThumbJob = nil;
        mySelf2 = nil;
    };
    [_masterThumbJob addDependency:_masterPreviewJob];
    [queue addOperation:_masterThumbJob];

}

static NSString* const kCrashWatchdog = @"CrashWatchdog";
static NSString* const kCrashRecipe = @"CrashRecipe";
static NSString* const kCrashAssetURL = @"CrashAssetURL";

- (BOOL)crashedOnPreviousRun {
    //[self completedWithoutCrashing];
    return [[NSUserDefaults standardUserDefaults] integerForKey:kCrashWatchdog] != 0;
}

- (void)ignorePreviousCrash {
    DDLogInfo(@"ignore previous crash");
    [self resetCrashingState];
}

- (void)crashRecoverIfPossible {
    if ([self crashedOnPreviousRun]) {
        currentlyHandlingCrash = YES;
        NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
        NSString* recipeCode = [userDefaults stringForKey:kCrashRecipe];
        NSURL* assetURL = [userDefaults URLForKey:kCrashAssetURL];

        DDLogError(@"attempting to recover from previous crash: %@ %@", recipeCode, assetURL);

        TRAssetLibraryImageProvider* provider = [[TRAssetLibraryImageProvider alloc] initWithAssetURL:assetURL];
        [self setImageProvider:provider];
        [self startImageProviderJobs];

        TRRecipe* recipe = [[TRRecipe alloc] initWithCode:recipeCode];
        CGImageRef rendered = [recipe applyToCGImage:self.masterPreview.CGImage masterSize:largeSize];
        crashPreview = [UIImage imageWithCGImage:rendered
                                           scale:self.masterPreview.scale
                                     orientation:self.masterPreview.imageOrientation];
        CGImageRelease(rendered);
        DDLogError(@"set crashPreview to %p", crashPreview);
    }
}

#define WANT_CRASH_RECOVERY

#ifndef WANT_CRASH_RECOVERY
#warning crash recovery disabled!!!
#endif

- (void)beginCrashyRegionForURL:(NSURL*)assetURL recipe:(NSString*)recipe {
  #ifndef WANT_CRASH_RECOVERY
    DDLogInfo(@"*** crash recovery disabled (for now) ***");
    return;
  #endif

    if (!currentlyHandlingCrash) {
        DDLogInfo(@"begin crashy region: %@ %@", recipe, assetURL);
        NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
        [userDefaults setInteger:1 forKey:kCrashWatchdog];
        [userDefaults setObject:recipe forKey:kCrashRecipe];
        [userDefaults setURL:assetURL forKey:kCrashAssetURL];
        [userDefaults synchronize];
    }
}

- (void)resetCrashingState {
    crashPreview = nil;

    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setInteger:0 forKey:kCrashWatchdog];
    [userDefaults removeObjectForKey:kCrashRecipe];
    [userDefaults removeObjectForKey:kCrashAssetURL];
    [userDefaults synchronize];

    currentlyHandlingCrash = NO;
}

- (void)completedWithoutCrashing {
    DDLogInfo(@"completed without crashing");
    [self resetCrashingState];
}

// #define this to cause frequent crashes during Tap -> Go transition
#undef WANT_FREQUENT_CRASHES

- (void)crashMe:(float)likelihood {
    // belt and suspenders: make sure "crashMe" NEVER happens in shipped builds
  #if defined(CONFIGURATION_Alpha) || defined(CONFIGURATION_AppStore)
    return;
  #endif

  #ifdef WANT_FREQUENT_CRASHES
  #warning Using the "crashMe" method to induce frequent crashes!!!
    if (currentlyHandlingCrash)
        return;
    const uint32_t r2 = 100000 * likelihood;
    uint32_t r1 = arc4random_uniform(100000);
    NSAssert(r1 > r2, @"random crash (via crashMe method)");
  #endif
}

- (void)crashMe {
    [self crashMe:0.40];
}

- (void)startResizingForShareView {
    DDLogWarn(@"startResizingForShareView startCurrentLargeJob");
    id<TRImageProvider> imgProvider = _imageProvider;
    NSURL* imageURL = imgProvider.assetURL;
    NSString *code = [self gatherEntireRecipeCode];

    [self beginCrashyRegionForURL:imageURL recipe:code];

    [self startCurrentLargeJob];
}

- (void)editViewWillAppear {
    savedCurrentPreview = nil;
}

- (void)editViewWillDisappear {
    [self.currentStep cancelSpeculativeThumbnails];
}

- (UIImage*)newMasterLarge {
    UIImage* large = nil;

    @autoreleasepool {
        TRUNUSED CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();

        id<TRImageProvider> imgProvider = self->_imageProvider;
        NSString* code = [self gatherEntireRecipeCode];

        DDLogInfo(@"*** newMasterLarge starting for %@ (mem %@)", code, stringWithMemoryInfo());
        UIImage* image = [imgProvider fullSizeImage];
        NSAssert(image, @"startMasterLargeJob block imgProvider fullSizeImage returned nil");

        [self crashMe];
        large = [image resizedImage:largeSize interpolationQuality:kCGInterpolationMedium];
        [self crashMe];

        CGSize sz = large.size;
        TRUNUSED CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
        DDLogInfo(@"*** newMasterLarge done for %@ (took %.3f) %.1fx%.1f (mem %@)",
          code, end - start, sz.width, sz.height, stringWithMemoryInfo());
    }

    DDLogInfo(@"masterLarge retain count %ld", CFGetRetainCount((__bridge CFTypeRef)large));
    return large;
}

- (UIImage*) masterPreview {
    if (_masterPreviewJob && !_masterPreviewJob.isFinished)
        [_masterPreviewJob waitUntilFinished];
    return _masterPreview;
}

- (UIImage*) masterThumb {
    if (_masterThumbJob && !_masterThumbJob.isFinished)
        [_masterThumbJob waitUntilFinished];
    return _masterThumb;
}

- (void)startCurrentLargeJob {
    if (!_currentLargeJob) {
        _currentLargeJob = [[LargeImageRunner alloc] initWithParent:self size:largeSize];
        [_currentLargeJob setQueuePriority:NSOperationQueuePriorityLow];
        [queue addOperation:_currentLargeJob];
    }
}

- (void)currentLargeWithWaitBlock:(WaitBlock)waitBlock
  completionBlock:(UIImageCompletionBlock)completionBlock {
    [self startCurrentLargeJob];
    if (!_currentLargeJob.isFinished)
        waitBlock();
    [_currentLargeJob setImageCompletionBlock:completionBlock];
}

- (void)setCurrentLarge:(UIImage*)currentLarge {
    _currentLarge = currentLarge;
}

- (UIImage*)currentLarge {
    [self startCurrentLargeJob];
    if (!_currentLargeJob.isFinished)
        [_currentLargeJob waitUntilFinished];
    return _currentLarge;
}

- (BOOL)currentLargeIsReady {
    return _currentLargeJob.isFinished;
}

- (NSString*)gatherEntireRecipeCode {
    NSString* recipeCode;
    if (currentlyHandlingCrash) {
        DDLogError(@"in gatherEntireRecipeCode, crashed on previous run");
        recipeCode = [[NSUserDefaults standardUserDefaults] stringForKey:kCrashRecipe];
    } else {
        recipeCode = [[self currentStep] cumulativeRecipeCode];
    }
    return recipeCode;
}

- (UIImage*)finalFullRez {
    TRRecipe *myRecipe = [[TRRecipe alloc] initWithCode:[self gatherEntireRecipeCode]];

    UIImage* fullRez = [_imageProvider fullSizeImage];
    DDLogInfo(@"finalFullRez dimensions %.1fx%.1f",
      fullRez.size.width, fullRez.size.height);
    CGImageRef rendered = [myRecipe applyToCGImage:fullRez.CGImage masterSize:largeSize];
    UIImage *outputImage = [UIImage imageWithCGImage:rendered
      scale:fullRez.scale orientation:fullRez.imageOrientation];
    CGImageRelease(rendered);

    return outputImage;
}

- (NSUInteger)styletCountInSection:(NSInteger)section {
    NSArray* a = [allRecipesInAllFolders objectAtIndex:section];
    if (section == kStyletFolderIDHistory || section == kStyletFolderIDMagic)
        return MAX(1, a.count);
    else if (section == kStyletFolderIDLibrary) {
        if (![MKStoreManager featurePurchased1]) {
            return a.count - 10;
        }
    }
    return a.count;
}

- (AppliedRecipeStep*)currentStep {
    NSArray* steps = self.appliedStepsList;
    NSAssert(_currentStepIndex >= 0, @"currentStep not positive");
    NSAssert(_currentStepIndex < steps.count, @"currentStep larger than appliedStepsList count");
    return [steps objectAtIndex:_currentStepIndex];
}

- (AppliedRecipeStep*)previousStep {
    NSArray* steps = self.appliedStepsList;
    NSAssert(_currentStepIndex >= 0, @"currentStep not positive (in previousStep)");
    NSAssert(_currentStepIndex < steps.count, @"currentStep larger than appliedStepsList count (in previousStep");
    if (_currentStepIndex <= 0)
        return nil;
    return [steps objectAtIndex:_currentStepIndex - 1];
}

- (UIImage*)thumbnailForRecipeStep:(NSUInteger)stepNumber {
    AppliedRecipeStep* step = [self.appliedStepsList objectAtIndex:stepNumber];
    return [step currentThumbAtCurrentStrength];
}

- (void)thumbnailCodeRendered:(NSNotification*)notification {
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationThumbnailIndexRendered
      object:self userInfo:nil];
}

- (BOOL)isJustEmpty {
    return [self.appliedStepsList count] <= 1;
}

- (BOOL)hasRecipesOrHistoryOrMagic {
    __block BOOL found = NO;
    [allRecipesInAllFolders enumerateObjectsUsingBlock:^(NSArray* folder, NSUInteger idx, BOOL *stop){
        if (idx != kStyletFolderIDLibrary) {
            if (folder.count > 0) {
                found = YES;
                *stop = YES;
            }
        }
    }];
    return found;
}

- (NSString*)codeAtIndexPath:(NSIndexPath*)indexPath {
    NSArray* section = [allRecipesInAllFolders objectAtIndex:indexPath.section];
    if (indexPath.row >= section.count)
        return @"";
    return [section objectAtIndex:indexPath.row];
}

- (ThumbnailAttributes*)styletAttributesForRecipeStep:(NSUInteger)stepNumber {
    AppliedRecipeStep* step = [self.appliedStepsList objectAtIndex:stepNumber];
    ThumbnailAttributes* attr = [[ThumbnailAttributes alloc] initWithCode:step.baseCode];
    attr.strength = step.strength.integerValue;
    return attr;
}

- (ThumbnailAttributes*)styletAttributesAtIndexPath:(NSIndexPath*)indexPath {
    return [[ThumbnailAttributes alloc] initWithCode:[self codeAtIndexPath:indexPath]];
}

- (UIImage*)styletThumbnailAtIndexPath:(NSIndexPath*)indexPath {
    AppliedRecipeStep* step = [self currentStep];
    NSString* code = [self codeAtIndexPath:indexPath];
    return [step thumbnailForCode:code];
}

- (void)moveStyletAtIndexPath:(NSIndexPath*)srcIndex toIndexPath:(NSIndexPath*)dstIndex {
    if ([srcIndex isEqual:dstIndex]) {
        // nothing to do
        return;
    }

    // These three lines swap the element in the styletLibrary array
    id item = [styletLibrary objectAtIndex:srcIndex.item];
    [styletLibrary removeObjectAtIndex:srcIndex.item];
    [styletLibrary insertObject:item atIndex:dstIndex.item];

    [self setupAllRecipesInAllFolders];
    [self saveStyletList];
}

- (void)resetCurrentLarge {
    NSOperation* job = _currentLargeJob;
    if (job) {
        [job cancel];
        [job waitUntilFinished];
    }
    _currentLargeJob = nil;
    _currentLarge = nil;
}

- (void)dumpRecipeSteps:(NSString*)prefix {
    AppliedRecipeStep* prev = nil;
    int count = 0;
    NSArray* steps = self.appliedStepsList;
    for (AppliedRecipeStep* step in steps) {
        DDLogInfo(@"%@step %d: %@", prefix, count, [step debugDescription]);
        if (prev && step.previousStep != prev) {
            DDLogError(@"previousStep is inconsistent!");
        }
        prev = step;
        ++count;
    }
}

- (void)replaceStepAtIndex:(NSUInteger)index withCode:(NSString*)code
  atStrength:(NSNumber*)strength
{
    if (index == 0) {
        // can't replace the initial no-op step, but must restart thumbnails
        [[self.appliedStepsList objectAtIndex:0] rebuildThumbnails];
        return;
    }

    NSMutableArray* steps = [NSMutableArray arrayWithArray:self.appliedStepsList];

    AppliedRecipeStep* curStep = [steps objectAtIndex:index];
    [curStep cancel];
    [curStep releaseMemoryForEditView];

    AppliedRecipeStep* prev = [steps objectAtIndex:index - 1];
    AppliedRecipeStep* newStep =
      [prev newStepByApplyingRecipeCode:code withStrength:strength];

    if (index < steps.count - 1) {
        AppliedRecipeStep* next = [steps objectAtIndex:index + 1];
        [next changePreviousStepTo:newStep];
        for (AppliedRecipeStep* step in steps) {
            if (step != next)
                [step releaseMemoryForEditView];
        }
    }

    [steps setObject:newStep atIndexedSubscript:index];
    self.appliedStepsList = steps;
    
    [self dumpRecipeSteps:[NSString stringWithFormat:@"replaceStepAtIndex %zd with %p, ", index, newStep]];
}

- (void)applyStyletWithCode:(NSString*)code {
    [self pruneRedoState];

    NSMutableArray* steps = [NSMutableArray arrayWithArray:self.appliedStepsList];
    AppliedRecipeStep* newStep = [[self currentStep]
      newStepByApplyingRecipeCode:code withStrength:@100.0];
    [steps addObject:newStep];
    self.appliedStepsList = steps;

    ++_currentStepIndex;
    if (_currentStepIndex == 2)
        [TRStatistics checkpoint:TRCheckpointStackedTwo];
    if (_currentStepIndex == 5)
        [TRStatistics checkpoint:TRCheckpointStackedFive];

    [self dumpRecipeSteps:@"applyStyletWithCode"];
}

- (void)applyStyletWithIndexPath:(NSIndexPath*)indexPath {
    NSString* code = [self codeAtIndexPath:indexPath];
    [self applyStyletWithCode:code];
}

- (BOOL)undoAppliedStylet {
    if (![self isJustEmpty] && _currentStepIndex > 0) {
        [TRStatistics checkpoint:TRCheckpointUsedUndo];

        AppliedRecipeStep* current = [self currentStep];
        NSAssert(current, @"current is nil in undoAppliedStylet");
        [current cancel];

        --_currentStepIndex;
        current = [self currentStep];
        NSAssert(current, @"new current is nil in undoAppliedStylet");
        [self replaceStepAtIndex:_currentStepIndex withCode:current.baseCode atStrength:current.strength];

        return YES;
    }
    return NO;
}

- (BOOL)redoAppliedStylet {
    if (![self isJustEmpty] && _currentStepIndex < self.appliedStepsList.count - 1) {
        [TRStatistics checkpoint:TRCheckpointUsedRedo];
        AppliedRecipeStep* current = [self currentStep];
        NSAssert(current, @"current is nil in redoAppliedStylet");
        [current cancel];
        [self replaceStepAtIndex:_currentStepIndex withCode:current.baseCode atStrength:current.strength];

        ++_currentStepIndex;
        current = [self currentStep];
        NSAssert(current, @"new current is nil in redoAppliedStylet");
        [self replaceStepAtIndex:_currentStepIndex withCode:current.baseCode atStrength:current.strength];

        return YES;
    }
    return NO;
}

- (void)pruneRedoState {
    NSArray* steps = self.appliedStepsList;
    const NSUInteger length = (steps.count - 1) - _currentStepIndex;
    if (length > 0) {
        NSMutableArray* newSteps = [NSMutableArray arrayWithArray:steps];
        [newSteps removeObjectsInRange:NSMakeRange(_currentStepIndex + 1, length)];
        self.appliedStepsList = newSteps;
    }
    [sharedTo removeAllObjects];
    [self resetCurrentLarge];
}

- (void)rebuildCurrentThumbnails {
    DDLogInfo(@"rebuildCurrentThumbnails does nothing");
    [[self currentStep] rebuildThumbnails];
}

- (void)editViewNowShowingSections:(NSArray*)sections andIndexPaths:(NSArray*)indexPaths {
    NSMutableArray* visibleCodes = [[NSMutableArray alloc] init];
    for (NSIndexPath* p in indexPaths) {
        if (p.section >= allRecipesInAllFolders.count || p.section < 0) {
            DDLogError(@"%@ section outside range 0..%zd", p, allRecipesInAllFolders.count);
            continue;
        }
        NSArray* a = [allRecipesInAllFolders objectAtIndex:p.section];
        if (p.row >= a.count || p.row < 0) {
            DDLogError(@"%@ row outside range 0..%zd", p, a.count);
            continue;
        }
        NSString* code = [[allRecipesInAllFolders objectAtIndex:p.section] objectAtIndex:p.row];
        [visibleCodes addObject:code];
    }

    AppliedRecipeStep* step = [self currentStep];
    step.visibleCodes = visibleCodes;
}

- (void)resetAppliedTools {
    [self setCropImageOrientation:UIImageOrientationUp];
    [self setCropSourceImageSize:CGSizeMake(0.0, 0.0)];

    [self setCropTransform:CGAffineTransformIdentity];
    [self setCropAspectRatio:self.masterPreview.size.width / self.masterPreview.size.height];
}

- (void)resetRecipe {
    DDLogInfo(@"resetRecipe");
    _currentStepIndex = -1;

    [self cancelEntireRecipe];
    [self resetCurrentLarge];

    UIImage* preview = self.masterPreview;
    UIImage* thumb = self.masterThumb;
    NSAssert(preview, @"preview is nil in resetRecipe");
    NSAssert(preview.CGImage, @"preview.CGImage is nil in resetRecipe");

    AppliedRecipeStep *firstStep = [AppliedRecipeStep newFirstStepIn:self
      masterSize:largeSize preview:preview thumb:thumb
      allRecipeCodes:allRecipesInAllFolders];

    NSMutableArray* steps = [[NSMutableArray alloc] init];
    [steps addObject:firstStep];
    self.appliedStepsList = steps;
    _currentStepIndex = 0;

    [self dumpRecipeSteps:@"resetRecipe "];
}

- (void)deleteAllRecipes {
    [TRStatistics deleteAllNames];
}

- (void)deleteAllHistory {
    [TRStatistics deleteAllHistory];
}

- (void)resetMagic {
    [TRStatistics resetMagic];
}

- (void)resetUnlockedFilters {
    [TRStatistics resetUnlockedFilters];
}

- (BOOL)currentFilterChainIsViableAsRecipe {
    if ([self isJustEmpty])
        return false;
    NSArray* steps = self.appliedStepsList;
    // remember, the first step is always TRempty (no-op stylet)
    if (steps.count > 2)
        return true;
    AppliedRecipeStep* s = [steps objectAtIndex:1];
    return (s.strength.floatValue < 99.0);
}

- (BOOL)hasFiltersApplied {
    if ([self isJustEmpty])
        return false;
    NSArray* steps = self.appliedStepsList;
    // remember, the first step is always TRempty (no-op stylet)
    if (steps.count > 1)
        return true;
    return false;
}

- (NSString *) importRecipeFromURL:(NSURL *)url {
    NSString *retName = [TRStatistics importRecipeFromURL:url];

    if (retName) {
        [self loadUserRecipeList];
        [self setupAllRecipesInAllFolders];
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationRecipeImported
          object:self userInfo:[NSDictionary dictionaryWithObject:retName forKey:@"recipeName"]];
    }

    return retName;
}

- (void)importRecipeBatch:(NSString*)recipeBatch {
    NSArray* recipes = [recipeBatch componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    BOOL anyImported = NO;
    for (NSString* recipe in recipes) {
        if (recipe.length > 0) {
            NSURL* url = [NSURL URLWithString:recipe];
            anyImported |= ([TRStatistics importRecipeFromURL:url] != nil);
        }
    }
    if (anyImported) {
        [self loadUserRecipeList];
        [self setupAllRecipesInAllFolders];
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationRecipeImported
          object:self userInfo:[NSDictionary dictionaryWithObject:@"Recipes" forKey:@"recipeName"]];
    }
}

- (void)deleteRecipeAtIndexPath:(NSIndexPath*)indexPath {
    NSString* code = [self codeAtIndexPath:indexPath];
    [TRStatistics deleteNameForCode:code];
    [self loadUserRecipeList];
    [self setupAllRecipesInAllFolders];
}

- (BOOL)assignRecipeName:(NSString*)name atIndexPath:(NSIndexPath*)indexPath {
    NSString* code = [self codeAtIndexPath:indexPath];
    return [self assignRecipeName:name withCode:code];
}

- (BOOL)assignRecipeName:(NSString*)name withCode:(NSString*)code {
    NSString* oldName = [TRStatistics recipeCode:code assignedName:name];
    BOOL dataChanged = NO;
    if (!oldName) {
        dataChanged = YES;
    } else {
        dataChanged = ![name isEqual:oldName];
    }
    if (dataChanged)
        [self loadUserRecipeList];

    [self setupAllRecipesInAllFolders];
    return dataChanged;
}

- (BOOL)renameRecipeAtIndexPath:(NSIndexPath*)indexPath toName:(NSString*)newName {
    // just a wrapper right now; may need to revisit in case of duplicate names
    return [self assignRecipeName:newName atIndexPath:indexPath];
}

- (NSUInteger)appliedStepsCount {
    return [self.appliedStepsList count];
}

- (NSInteger)currentStepIndex {
    return _currentStepIndex;
}

- (NSNumber*)currentStrength {
    AppliedRecipeStep* step = [self currentStep];
    if (step)
        return step.strength;
    // Couldn't find step, so use a default
    return [NSNumber numberWithFloat:100.0];
}

- (void)setCurrentStrength:(NSNumber *)strength {
    AppliedRecipeStep* step = [self currentStep];
    if (step) {
        [self replaceStepAtIndex:_currentStepIndex
          withCode:step.baseCode atStrength:strength];
    }
}

- (UIImage*)currentPreviewAtFullStrength {
    AppliedRecipeStep* step = [self currentStep];
    if (step)
        return [step currentPreviewAtFullStrength];
    return self.masterPreview;
}

- (UIImage*)currentPreviewAtCurrentStrength {
    UIImage* tmp = savedCurrentPreview;
    if (tmp) {
        DDLogInfo(@"currentPreviewAtCurrentStrength returning savedCurrentPreview");
        return tmp;
    }
    if ([self crashedOnPreviousRun]) {
        [self crashRecoverIfPossible];
        DDLogError(@"in currentPreviewAtCurrentStrength, crashed on previous run (%p)", crashPreview);
        return crashPreview;
    }
    AppliedRecipeStep* step = [self currentStep];
    if (step) {
        DDLogInfo(@"currentPreviewAtCurrentStrength returning step %@", step.recipeCode);
        return [step resultPreview];
    }
    DDLogInfo(@"currentPreviewAtCurrentStrength returning masterPreview");
    return self.masterPreview;
}

- (UIImage*)originalPreview {
    id<TRImageProvider> original = _imageProvider.originalProvider;
    if (original)
        return [original previewSizeImage];
    return [_imageProvider previewSizeImage];
}

- (UIImage*)currentPreviewNoCrop {
    UIImage* orig = [self originalPreview];
    AppliedRecipeStep* step = [self currentStep];
    if (step)
        return [step renderPreviewNoCrop:orig];
    return nil;
}

- (UIImage*)currentThumbAtCurrentStrength {
    AppliedRecipeStep* step = [self currentStep];
    if (step)
        return [step currentThumbAtCurrentStrength];
    return nil;
}

- (UIImage*)previousPreview {
    AppliedRecipeStep* prev = [self previousStep];
    if (prev)
        return [prev resultPreview];
    return self.masterPreview;
}

- (UIImage*)previousThumb {
    AppliedRecipeStep* prev = [self previousStep];
    if (prev)
        return [prev currentThumbAtCurrentStrength];
    return nil;
}

- (NSString*)recipeCode {
    return [self currentStep].cumulativeRecipeCode;
}

- (void) saveRecipeToHistory {
    NSString* code = [self gatherEntireRecipeCode];
    [TRStatistics recipeWasUsed:code];
}

- (void) saveRecipeUsingName:(NSString*)name {
    NSString* code = [self gatherEntireRecipeCode];
    [self assignRecipeName:name withCode:code];
}

- (void) updateMagicWeights {
    NSString* code = [self gatherEntireRecipeCode];
    [TRStatistics updateMagicWeightsForCode:code];
}

- (BOOL)hasSharedToDestination:(NSString*)destination {
    return [sharedTo containsObject:destination];
}

- (void)didShareToDestination:(NSString*)destination {
    if (![self hasSharedToDestination:destination]) {
        [sharedTo addObject:destination];
        NSString* code = [self gatherEntireRecipeCode];
        [TRStatistics imageWasShared:destination usingRecipe:code];
    }
}

- (void)unlockRecipeCodeAndFollowURL:(NSString*)recipeCode {
    [TRStatistics unlockRecipeCodeAndFollowURL:recipeCode];
}

- (void)addStylet:(NSString*)strNewStylet {
    [styletLibrary addObject:strNewStylet];
}

@end

@implementation LargeImageRunner
enum RunState { STATE_READY, STATE_RUNNING, STATE_DONE };

- (LargeImageRunner*)initWithParent:(ImageDataController*)par size:(CGSize)theSize{
    self = [super init];
    if (self) {
        parent = par;
        state = [[NSConditionLock alloc] initWithCondition:STATE_READY];
        size = theSize;
        result = nil;
        imageCompletionBlock = nil;
    }
    return self;
}

- (void)main {
    [state lockWhenCondition:STATE_READY];
    [state unlockWithCondition:STATE_RUNNING];

    TRUNUSED CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    TRRecipe *myRecipe = [[TRRecipe alloc] initWithCode:[parent gatherEntireRecipeCode]];

    DDLogInfo(@"*** currentLargeJob starting (recipe \"%@\") (mem %@)",
      myRecipe.code, stringWithMemoryInfo());

    CGSize sz;
    UIImageOrientation orient;
    CGFloat scale;
    CGImageRef cgImage;
    @autoreleasepool {
        UIImage* image = [parent newMasterLarge];
        sz = image.size;
        orient = image.imageOrientation;
        scale = image.scale;
        cgImage = CGImageRetain(image.CGImage);
    }

    DDLogInfo(@"*** currentLargeJob (recipe \"%@\") (mem %@) image retain count %ld",
      myRecipe.code, stringWithMemoryInfo(), CFGetRetainCount(cgImage));
    NSAssert(cgImage, @"cgImage is nil in LargeImageRunner");

    [parent crashMe];
    CGImageRef rendered = [myRecipe consumeCGImage:cgImage masterSize:sz];
    DDLogInfo(@"*** currentLargeJob rendered %p retain count %ld",
      rendered, CFGetRetainCount(rendered));

    [parent crashMe];
    result = [UIImage imageWithCGImage:rendered scale:scale orientation:orient];
    [parent crashMe];
    CGImageRelease(rendered);

    parent.currentLarge = result;

    TRUNUSED CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    DDLogInfo(@"*** currentLargeJob done (took %.3f) %.1fx%.1f (mem %@) image retain count %ld",
      end - start, size.width, size.height, stringWithMemoryInfo(), CFGetRetainCount(rendered));
}

- (void (^)(void))completionBlock {
    return ^(){
        DDLogInfo(@"running LargeImageRunner completionBlock");
        [parent completedWithoutCrashing];

        UIImageCompletionBlock block = self->imageCompletionBlock;
        imageCompletionBlock = nil;
        parent = nil;

        [state lock];
        if (state.condition != STATE_READY)
            DDLogWarn(@"LargeImageRunner completionBlock in state %zd", state.condition);
        [state unlockWithCondition:STATE_DONE];

        if (block) {
            DDLogVerbose(@"completionBlock is %p", block);
            block(result);
        }
    };
}

- (void)setImageCompletionBlock:(UIImageCompletionBlock)block {
    DDLogInfo(@"setCompletionBlock %p", block);
    BOOL alreadyFinished = NO;
    [state lock];
    if (state.condition == STATE_DONE)
        alreadyFinished = YES;
    else
        imageCompletionBlock = block;
    [state unlock];
    if (alreadyFinished && block)
        block(result);
}
@end
