
//
//  AppliedRecipeStep.m
//  RadLab
//
//  Created by Geoff Scott on 11/28/12.
//  Copyright (c) 2012 Totally Rad. All rights reserved.
//

#import "ImageDataController.h"
#import "AppliedRecipeStep.h"
#import "TRRecipe.h"
#import "MemoryStatistics.h"
#import <libkern/OSAtomic.h>

static int ddLogLevel = LOG_LEVEL_INFO;

static volatile int thumbnailRendererCount;
static volatile int thumbnailRendererItemCount;
static volatile int appliedRecipeStepCount;

@interface AppliedRecipeStep ()
@property (strong, atomic) NSArray* visibleCodes;
@property (strong, atomic) NSArray* allRecipeCodes;
@end

// ----------------------------------------------------------------------

@interface Thumbnail : NSObject {
@public
    UIImage* image;
}
@end

@implementation Thumbnail
- (Thumbnail*)initWithImage:(UIImage*)img {
    self = [super init];
    if (self) {
        image = img;
    }
    return self;
}
@end

@interface SpinnerImage : Thumbnail
@end

@implementation SpinnerImage
@end

CF_RETURNS_RETAINED
CGImageRef applyRecipe(NSString* recipeCodeWithStrength, CGImageRef source,
  CGSize masterSize)
{
    NSCAssert(source, @"applyRecipe called without source");

    // Compose the recipe
    TRRecipe* myRecipe = [[TRRecipe alloc] init];
    NSCAssert(myRecipe, @"applyRecipe myRecipe is nil");

    [myRecipe append:recipeCodeWithStrength];

    CGImageRef result = [myRecipe applyToCGImage:source masterSize:masterSize];
    NSCAssert(result, @"applyRecipe returning nil");

    return result;
}

NS_RETURNS_RETAINED
UIImage* applyRecipeToUIImage(NSString* recipeCodeWithStrength, UIImage* source,
  CGSize masterSize)
{
    CGImageRef r = applyRecipe(recipeCodeWithStrength, source.CGImage, masterSize);
    NSCAssert(r, @"applyRecipeToUIImage r is nil");
    UIImage* result = [UIImage imageWithCGImage:r];
    NSCAssert(result, @"applyRecipeToUIImage result is nil");
    CGImageRelease(r);
    return result;
}

static void doOnce(NSConditionLock* lock, void(^block)()) {
    if ([lock tryLockWhenCondition:0]) {
        @autoreleasepool {
            block();
        }
        [lock unlockWithCondition:1];
    } else {
        [lock lockWhenCondition:1];
        [lock unlock];
    }
}

// ----------------------------------------------------------------------

@interface ThumbnailRendererItem : NSObject {
    NSString* recipeCode;
    NSString* codePrefix;
    NSConditionLock* renderLock;
    UIImage* _image;
}
- (id)initWithCode:(NSString*)code codePrefix:(NSString*)codePrefix;
- (UIImage*)image;
- (NSString*)code;
- (NSString*)prefixCode;
@end

@implementation ThumbnailRendererItem

- (void)dealloc
{
    [renderLock lock];
    [renderLock unlock];
    recipeCode = nil;
    codePrefix = nil;
    renderLock = nil;
    _image = nil;
    OSAtomicDecrement32(&thumbnailRendererItemCount);
}

- (id)initWithCode:(NSString*)code codePrefix:(NSString*)prefix {
    self = [super init];
    if (self) {
        OSAtomicIncrement32(&thumbnailRendererItemCount);
        DDLogVerbose(@"ThumbnailRendererItem initWithCode \"%@\" + \"%@\"", code, prefix);
        recipeCode = code;
        codePrefix = prefix;
        renderLock = [[NSConditionLock alloc] initWithCondition:0];
    }
    return self;
}

- (UIImage*)image {
    if ([renderLock tryLockWhenCondition:1]) {
        [renderLock unlock];
        return _image;
    }
    return nil;
}

- (void)render:(UIImage*)sourceImage masterSize:(CGSize)masterSize cache:(NSCache*)cache {
    doOnce(renderLock, ^(){
        [self _render:sourceImage masterSize:masterSize cache:cache];
    });
}
- (void)_render:(UIImage*)sourceImage masterSize:(CGSize)masterSize cache:(NSCache*)cache {
    NSString* fullCode = [codePrefix stringByAppendingString:recipeCode];

    Thumbnail* cached = [cache objectForKey:fullCode];
    if (cached) {
        _image = cached->image;
        DDLogVerbose(@"found thumbnail \"%@\"+\"%@\" in cache",
          codePrefix, recipeCode);
    } else {
        CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
        CGImageRef r = applyRecipe(recipeCode, sourceImage.CGImage, masterSize);
        UIImage* img = [UIImage imageWithCGImage:r];
        _image = img;
        CGImageRelease(r);
        CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
        __attribute__((unused)) CFTimeInterval elapsed = end - start;
        DDLogVerbose(@"thumbnail \"%@\"+\"%@\" %@ (%.6fs)",
          codePrefix, recipeCode, img, elapsed);
        [cache setObject:[[Thumbnail alloc] initWithImage:img] forKey:fullCode];
    }
}

- (NSString*)code {
    return recipeCode;
}
- (NSString*)prefixCode {
    return codePrefix;
}

@end

// ----------------------------------------------------------------------

@interface ThumbnailRenderer : NSObject {
    UIImage* sourceImage;
    SpinnerImage* _spinnerImage;
    NSConditionLock* spinnerImageLock;
    CGSize masterSize;
    NSString* codePrefix;
    NSCache* cache;
    NSMutableDictionary* results;
    NSOperationQueue* renderingQueue;
    BOOL cancelled;
}
- (id)initWithStep:(AppliedRecipeStep*)step image:(UIImage*)image masterSize:(CGSize)masterSize
  codePrefix:(NSString*)codePrefix cache:(NSCache*)cache;
- (void)cancel;
- (void)purge;
@property (weak, atomic) AppliedRecipeStep* step;
@end

@implementation ThumbnailRenderer

- (void)dealloc
{
    int rendererCount = OSAtomicDecrement32Barrier(&thumbnailRendererCount);
    int itemCount = thumbnailRendererCount;
    DDLogInfo(@"ThumbnailRenderer dealloc %p %@ (%d renderers with %d items) (mem %@)",
      self, codePrefix, rendererCount, itemCount, stringWithMemoryInfo());

    [spinnerImageLock lock];
    _spinnerImage = nil;
    [spinnerImageLock unlock];
    spinnerImageLock = nil;
    sourceImage = nil;
    codePrefix = nil;
    cache = nil;
    results = nil;
    renderingQueue = nil;

    DDLogInfo(@"ThumbnailRenderer dealloc %p %@ done", self, codePrefix);
}

- (id)initWithStep:(AppliedRecipeStep*)step image:(UIImage*)img masterSize:(CGSize)masterSz
  codePrefix:(NSString*)code cache:(NSCache*)tcache
{
    self = [super init];
    DDLogInfo(@"ThumbnailRenderer initWithStep %p %@", self, codePrefix);
    if (self) {
        OSAtomicIncrement32Barrier(&thumbnailRendererCount);
        self.step = step;
        sourceImage = img;
        masterSize = masterSz;
        cache = tcache;
        codePrefix = code;
        results = [[NSMutableDictionary alloc] init];
        spinnerImageLock = [[NSConditionLock alloc] initWithCondition:0];

        renderingQueue = [[NSOperationQueue alloc] init];
        renderingQueue.maxConcurrentOperationCount = 1;

        [self renderSpinner];
        [self spawnRenderingJobs];
    }
    return self;
}

- (void)spawnRenderingJobs {
    AppliedRecipeStep* step = self.step;
    if (!step) {
        DDLogWarn(@"spawnRenderingJobs step is nil, returning immediately");
        return;
    }
    int count = 0;
    NSArray* allRecipeCodes = step.allRecipeCodes;
    if (!allRecipeCodes) {
        DDLogWarn(@"spawnRenderingJobs allRecipeCodes is nil, returning immediately");
        return;
    }
    for (NSArray* a in allRecipeCodes) {
        for (NSString* code in a)
            ++count;
    }
    DDLogWarn(@"*** spawning %d jobs to render thumbnails ***", count);
    for (int i = 0; i < count; ++i)
        [self renderSomeThumbnail];
}

- (void)cancel {
    DDLogVerbose(@"ThumbnailRenderer cancel %p", self);
    cancelled = YES;
    [renderingQueue cancelAllOperations];
}

- (void)purge {
    [self cancel];
    [renderingQueue waitUntilAllOperationsAreFinished];
    NSUInteger count;
    @synchronized (results) {
        count = results.count;
        [results removeAllObjects];
    }
    if (count > 0)
        DDLogInfo(@"renderer purged %zd thumbnails", count);
    sourceImage = nil;
    [spinnerImageLock lock];
    _spinnerImage = nil;
    [spinnerImageLock unlockWithCondition:0];
}

- (SpinnerImage*)spinnerImageFor:(UIImage*)source {
    static dispatch_once_t once;
    static UIImage* overlay = nil;
    dispatch_once(&once, ^{
        overlay = [UIImage animatedImageNamed:@"loading-" duration:1.0];
    });
    if (cancelled) {
        DDLogWarn(@"spinnerImageFor cancelled, returning nil");
        return nil;
    }
    if (!source) {
        DDLogWarn(@"spinnerImageFor source is nil, returning plain spinner");
        return [[SpinnerImage alloc] initWithImage:overlay];
    }
    @autoreleasepool {
        NSArray* spinnerImages = [overlay images];
        NSMutableArray* animation = [[NSMutableArray alloc] initWithCapacity:spinnerImages.count];

        UIImage* const s0 = [spinnerImages objectAtIndex:0];
        const CGSize s0size = CGSizeMake(
          s0.size.width * s0.scale * s0.scale / 4.0,
          s0.size.height * s0.scale * s0.scale / 4.0);
        const CGRect pos = CGRectMake(
          (source.size.width - s0size.width) / 2.0,
          (source.size.height - s0size.height) / 2.0,
          s0size.width, s0size.height);
        for (UIImage* cell in spinnerImages) {
            if (cancelled) {
                DDLogWarn(@"spinnerImageFor cancelled in loop, returning nil");
                return nil;
            }
            UIGraphicsBeginImageContextWithOptions(source.size, NO, 0.0);
            [source drawAtPoint:CGPointZero];
            [cell drawInRect:pos blendMode:kCGBlendModeNormal alpha:1.0];
            UIImage* img = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            [animation addObject:img];
        }
        return [[SpinnerImage alloc] initWithImage:[UIImage animatedImageWithImages:animation duration:1.0]];
    }
}

- (UIImage*)spinnerImage {
    doOnce(spinnerImageLock, ^(){
        _spinnerImage = [self spinnerImageFor:sourceImage];
    });
    if (!_spinnerImage)
        return nil;
    return _spinnerImage->image;
}

- (ThumbnailRendererItem*)searchArrayForItemToRender:(NSArray*)array {
    ThumbnailRendererItem* item = nil;

    // Find some work that hasn't been done yet
    for (NSString* c in array) {
        @synchronized (results) {
            item = [results objectForKey:c];
        }
        if (!item) {
            // If it doesn't exist, create a new one
            item = [[ThumbnailRendererItem alloc] initWithCode:c codePrefix:codePrefix];
            @synchronized (results) {
                // MIGHT HAVE BEEN ADDED ON ANOTHER THREAD!  If not, add it.
                // If it has, loop again (try another)
                if (![results objectForKey:c]) {
                    [results setObject:item forKey:c];
                    return item;
                }
            }
        }
    }
    return nil;
}

- (ThumbnailRendererItem*)findItemToRender {
    if (cancelled) {
        DDLogInfo(@"renderer cancelled, so returning nil Item");
        return nil;
    }

    AppliedRecipeStep* step = self.step;
    if (!step) {
        DDLogWarn(@"findItemToRender step is nil, returning nil Item");
        return nil;
    }

    NSArray* visibleCodes = step.visibleCodes;
    NSArray* allRecipeCodes = step.allRecipeCodes;
    if (!allRecipeCodes) {
        DDLogWarn(@"findItemToRender allRecipeCodes is nil, so returning nil Item");
        return nil;
    }

    if (NO) {
        NSString* visibleCodesStr = @"(none)";
        if (visibleCodes)
            visibleCodesStr = [visibleCodes componentsJoinedByString:@","];
        NSMutableString* allCodesStr = [[NSMutableString alloc] init];
        for (NSArray* a in allRecipeCodes) {
            [allCodesStr appendString:@"("];
            [allCodesStr appendString:[a componentsJoinedByString:@","]];
            [allCodesStr appendString:@")"];
        }
        DDLogInfo(@"visibleCodes %@; allCodes %@", visibleCodesStr, allCodesStr);
    }

    ThumbnailRendererItem* item;

    // First look for stuff that's on-screen
    item = [self searchArrayForItemToRender:visibleCodes];
    if (item)
        return item;

    // A small hack: prefer to render Stylets in order, instead of in the
    // order they appear in "My Style"
    NSAssert(allRecipeCodes.count > kStyletFolderIDLibrary, @"allRecipeCodes.count=%zd", allRecipeCodes.count);
    NSArray* folder = [allRecipeCodes objectAtIndex:kStyletFolderIDLibrary];
    item = [self searchArrayForItemToRender:folder];
    if (item)
        return item;

    // Find ANY work that hasn't been done yet
    for (NSArray* a in allRecipeCodes) {
        item = [self searchArrayForItemToRender:a];
        if (item)
            return item;
    }

    NSArray* resultsKeys = nil;
    @synchronized (results) {
        resultsKeys = [[results allKeys] copy];
    }

    // Couldn't find anything to do; sanity check this fact
    NSMutableSet* allCodes = [[NSMutableSet alloc] init];
    for (NSArray* a in allRecipeCodes)
        [allCodes addObjectsFromArray:a];
    NSMutableSet* resultsCodes = [[NSMutableSet alloc] init];
    [resultsCodes addObjectsFromArray:resultsKeys];
    NSMutableSet* missing = [allCodes mutableCopy];
    [missing minusSet:resultsCodes];
    if (missing.count > 0) {
        DDLogWarn(@"!!! FOUND NO ITEM TO RENDER! results contains %@ (missing %@)", [resultsKeys componentsJoinedByString:@","],
          [[missing allObjects] componentsJoinedByString:@","]);
        for (NSArray* a in allRecipeCodes) {
            for (NSString* c in a) {
                if (![resultsKeys containsObject:c])
                    DDLogInfo(@"lookup %@ not in %@", c, [resultsKeys componentsJoinedByString:@","]);
            }
        }
    }

    return nil;
}

- (void)renderSpinner {
    __block ThumbnailRenderer* mySelf = self;
    NSOperation* op = [NSBlockOperation blockOperationWithBlock:^(){
        [mySelf spinnerImage];
      }];
    op.completionBlock = ^(){ mySelf = nil; };
    op.queuePriority = NSOperationQueuePriorityHigh;
    [renderingQueue addOperation:op];
}

- (void)renderSomeThumbnail {
    __block ThumbnailRenderer* mySelf = self;
    NSOperation* op = [NSBlockOperation blockOperationWithBlock:^(){
        UIImage* img = mySelf->sourceImage;
        if (!img) {
            DDLogVerbose(@"renderSomeThumbnail sourceImage is nil");
            return;
        }

        NSCache* cch = mySelf->cache;
        if (!cch) {
            DDLogWarn(@"renderSomeThumbnail cache is nil");
            return;
        }

        ThumbnailRendererItem* item = [mySelf findItemToRender];
        if (item) {
            DDLogVerbose(@"renderSomeThumbnail %p begin %p %@ %@%s", mySelf, item, item.prefixCode, item.code,
              mySelf->cancelled ? " CANCELLED" : "");
            [item render:img masterSize:mySelf->masterSize cache:mySelf->cache];
            [[NSNotificationCenter defaultCenter]
              postNotificationName:kNotificationThumbnailCodeRendered object:nil
              userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                item.code, @"code",
                item.prefixCode, @"codePrefix",
                nil]];
            DDLogVerbose(@"renderSomeThumbnail %p end %p %@ %@%s", mySelf, item, item.prefixCode, item.code,
              mySelf->cancelled ? " CANCELLED" : "");
        }
    }];
    op.completionBlock = ^(){ mySelf = nil; };
    [renderingQueue addOperation:op];
}

- (UIImage*)thumbnailForCode:(NSString*)code step:(AppliedRecipeStep*)step {
    @synchronized (results) {
        ThumbnailRendererItem* item = [results objectForKey:code];
        if (item) {
            UIImage* image = item.image;
            if (image) {
                DDLogVerbose(@"thumbnail for code %@ already rendered", code);
                return image;
            }
        }
    }
    [self renderSomeThumbnail];
    DDLogVerbose(@"thumbnail for code %@ will be rendered, returning spinner", code);
    return self.spinnerImage;
}
@end

// ----------------------------------------------------------------------

@interface AppliedRecipeStep () {
@private
    CGSize masterSize, previewSize, thumbnailSize;
    NSString* _baseCode;
    NSNumber* _strength;
    NSString* _recipeCode;

    UIImage* _sourcePreview;
    UIImage* _sourceThumb;

    NSOperationQueue* queue;

    UIImage* _resultPreview;
    NSConditionLock* resultPreviewLock;

    UIImage* _currentPreviewAtFullStrength;
    NSConditionLock* currentPreviewLock;

    UIImage* _currentThumbAtCurrentStrength;
    NSConditionLock* currentThumbLock;

    ThumbnailRenderer* renderer;
}
@property (weak) ImageDataController* parent;
@property (weak, atomic) AppliedRecipeStep* previousStep;
@end

@implementation AppliedRecipeStep
@synthesize visibleCodes = _visibleCodes;
@synthesize allRecipeCodes = _allRecipeCodes;

- (void)dealloc {
    int stepCount = OSAtomicDecrement32Barrier(&appliedRecipeStepCount);
    DDLogInfo(@"AppliedRecipeStep dealloc %@ (%d steps) (mem %@)",
      self, stepCount, stringWithMemoryInfo());
    [queue cancelAllOperations];
    [self purgeThumbnails];
    _baseCode = nil;
    _strength = nil;
    _recipeCode = nil;
    _sourcePreview = nil;
    _sourceThumb = nil;
    queue = nil;
    _resultPreview = nil;
    resultPreviewLock = nil;
    _currentPreviewAtFullStrength = nil;
    currentPreviewLock = nil;
    _currentThumbAtCurrentStrength = nil;
    currentThumbLock = nil;
    renderer = nil;
    DDLogInfo(@"AppliedRecipeStep dealloc %@ done", self);
}

- (AppliedRecipeStep*)initWithParent:(ImageDataController*)parent
  previousStep:(AppliedRecipeStep*)previousStep
  baseCode:(NSString*)baseCode strength:(NSNumber*)strength
  masterSize:(CGSize)theMasterSize preview:(UIImage*)preview thumb:(UIImage*)thumb
  allRecipeCodes:(NSArray*)allRecipeCodes
{
    self = [super init];
    if (!self)
        return self;

    OSAtomicIncrement32(&appliedRecipeStepCount);

    NSString* recipeCodeWithStrength = [AppliedRecipeStep recipeCode:baseCode withStrength:strength.integerValue];

    DDLogInfo(@"AppliedRecipeStep %p initWithParent: \"%@\" add \"%@\" (mem %@)",
      self, self.prefixRecipeCode, recipeCodeWithStrength, stringWithMemoryInfo());

    self.parent = parent;
    self.previousStep = previousStep;
    self.allRecipeCodes = allRecipeCodes;

    _sourcePreview = preview;
    _sourceThumb = thumb;
    _baseCode = baseCode;
    _strength = strength;
    _recipeCode = recipeCodeWithStrength;
    masterSize = theMasterSize;
    previewSize = self.sourcePreview.size;
    thumbnailSize = thumb.size;

    _resultPreview = nil;
    _currentPreviewAtFullStrength = nil;
    _currentThumbAtCurrentStrength = nil;

    resultPreviewLock = [[NSConditionLock alloc] initWithCondition:0];
    currentPreviewLock = [[NSConditionLock alloc] initWithCondition:0];
    currentThumbLock = [[NSConditionLock alloc] initWithCondition:0];

    queue = [[NSOperationQueue alloc] init];
    queue.maxConcurrentOperationCount = 1;
    {
        __block AppliedRecipeStep* mySelf = self;
        NSOperation* op = [NSBlockOperation blockOperationWithBlock:^(){
            [mySelf idempotentRenderThumbnail];
          }];
        op.completionBlock = ^(){ mySelf = nil; };
        [queue addOperation:op];
    }
    {
        __block AppliedRecipeStep* mySelf = self;
        NSOperation* op = [NSBlockOperation blockOperationWithBlock:^(){
            [mySelf idempotentRenderPreview];
          }];
        op.completionBlock = ^(){ mySelf = nil; };
        [queue addOperation:op];
    }

    renderer = [[ThumbnailRenderer alloc] initWithStep:self
      image:self.currentThumbAtCurrentStrength masterSize:masterSize
      codePrefix:[self accumulatedRecipeCode] cache:self.parent.thumbnailCache];

    return self;
}

+ (AppliedRecipeStep*)newFirstStepIn:(ImageDataController*)parent
  masterSize:(CGSize)masterSize preview:(UIImage*)preview thumb:(UIImage*)thumb
  allRecipeCodes:(NSArray*)allRecipeCodes
{
    AppliedRecipeStep* step = [[AppliedRecipeStep alloc]
      initWithParent:parent previousStep:nil baseCode:@"" strength:@100.0
      masterSize:masterSize preview:preview thumb:thumb allRecipeCodes:allRecipeCodes];
    return step;
}

- (AppliedRecipeStep*)newStepByApplyingRecipeCode:(NSString*)code
  withStrength:(NSNumber*)strength
{
    [self cancelSpeculativeThumbnails];
    [self promotePreview];
    [self purgeThumbnails];

    AppliedRecipeStep* newStep = [[AppliedRecipeStep alloc]
      initWithParent:self.parent previousStep:self
      baseCode:code strength:strength
      masterSize:masterSize preview:nil thumb:nil
      allRecipeCodes:nil];

    return newStep;
}

- (void)changePreviousStepTo:(AppliedRecipeStep*)newStep {
    self.previousStep = newStep;
    [self rebuildThumbnails];
}

- (void)rebuildThumbnails {
    if (renderer)
        [renderer purge];
    renderer = [[ThumbnailRenderer alloc] initWithStep:self
      image:self.currentThumbAtCurrentStrength masterSize:masterSize
      codePrefix:[self accumulatedRecipeCode] cache:self.parent.thumbnailCache];
}

- (void)changePreview:(UIImage*)preview thumb:(UIImage*)thumb {
    if (renderer)
        [renderer purge];
    NSAssert(!self.previousStep, @"Can't change preview/thumb except on first step");
    _sourcePreview = preview;
    _sourceThumb = thumb;
    renderer = [[ThumbnailRenderer alloc] initWithStep:self
      image:self.currentThumbAtCurrentStrength masterSize:masterSize
      codePrefix:[self accumulatedRecipeCode] cache:self.parent.thumbnailCache];
}

- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"self %p prefix '%@' code '%@' previous %p",
      self, self.prefixRecipeCode, self.recipeCode, self.previousStep];
}

- (void)idempotentRenderThumbnail {
    // build the thumbnail image with this step's recipe applied.

    doOnce(currentThumbLock, ^(){
        NSAssert(!_currentThumbAtCurrentStrength,
          @"idempotentRenderThumbnail currentThumbAtCurrentStrength already has a value");

        NSString* key = [self.prefixRecipeCode stringByAppendingString:_recipeCode];

        DDLogInfo(@"idempotentRenderThumbnail begin %@", key);
        Thumbnail* cached = [self.parent.thumbnailCache objectForKey:key];
        if (cached) {
            _currentThumbAtCurrentStrength = cached->image;
        } else {
            UIImage* img = self.sourceThumb;
            NSAssert(img, @"idempotentRenderThumbnail got no sourceThumb");
            UIImage* thumb = applyRecipeToUIImage(_recipeCode, img, masterSize);
            cached = [[Thumbnail alloc] initWithImage:thumb];
            [self.parent.thumbnailCache setObject:cached forKey:key];
            _currentThumbAtCurrentStrength = cached->image;
        }
        DDLogInfo(@"idempotentRenderThumbnail end %@", key);
    });

    if (!_currentThumbAtCurrentStrength)
        DDLogWarn(@"idempotentRenderThumbnail result is nil");
}

- (void)cancelThumbnail {
    if ([currentThumbLock tryLockWhenCondition:0])
        [currentThumbLock unlockWithCondition:1];
}

- (void)idempotentRenderPreview {
    // build the preview image with this step's baseCode
    // applied at full strength.  The UI will use the full-strength preview
    // alpha-blended with sourcePreview to implement the UI strength
    // presentation

    doOnce(currentPreviewLock, ^(){
        NSAssert(!_currentPreviewAtFullStrength,
          @"idempotentRenderPreview currentPreviewAtFullStrength already has a value");

        NSString* key = [self.prefixRecipeCode stringByAppendingString:self.baseCode];

        DDLogInfo(@"idempotentRenderPreview begin %@", key);
        UIImage* result = [self.parent.previewCache objectForKey:key];
        if (!result) {
            UIImage* img = self.sourcePreview;
            NSAssert(img, @"idempotentRenderPreview got no sourcePreview");
            result = applyRecipeToUIImage(self.baseCode, img, masterSize);
            [self.parent.previewCache setObject:result forKey:key];
            DDLogInfo(@"idempotentRenderPreview rendered %p for %@", result, key);
        } else {
            DDLogInfo(@"idempotentRenderPreview found cached result %p for %@", result, key);
        }
        _currentPreviewAtFullStrength = result;
        DDLogInfo(@"idempotentRenderPreview end %@", key);
    });

    if (!_currentPreviewAtFullStrength)
        DDLogWarn(@"idempotentRenderPreview returning nil");
}

- (void)cancelPreview {
    if ([currentPreviewLock tryLockWhenCondition:0])
        [currentPreviewLock unlockWithCondition:1];
}

- (void)idempotentRenderResult {
    doOnce(resultPreviewLock, ^(){
        NSAssert(!_resultPreview,
          @"idempotentRenderResult resultPreview already has a value");

        NSString* key = [self.prefixRecipeCode stringByAppendingString:_recipeCode];

        DDLogInfo(@"idempotentRenderResult begin %@", key);
        UIImage* result = [self.parent.previewCache objectForKey:key];
        if (!result) {
            UIImage* img = self.sourcePreview;
            NSAssert(img, @"idempotentRenderResult got no sourcePreview");
            result = applyRecipeToUIImage(_recipeCode, img, masterSize);
            [self.parent.previewCache setObject:result forKey:key];
            DDLogInfo(@"idempotentRenderResult rendered %p for %@", result, key);
        } else {
            DDLogInfo(@"idempotentRenderResult found cached result %p for %@", result, key);
        }
        _resultPreview = result;
        DDLogInfo(@"idempotentRenderResult end %@", key);
    });

    if (!_resultPreview)
        DDLogWarn(@"idempotentRenderResult returning nil");
}

- (void)cancelResult {
    if ([resultPreviewLock tryLockWhenCondition:0])
        [resultPreviewLock unlockWithCondition:1];
}

- (void)cancelSpeculativeThumbnails {
    DDLogWarn(@"cancelSpeculativeThumbnails begin %@", _recipeCode);
    [renderer cancel];
    DDLogWarn(@"cancelSpeculativeThumbnails end %@", _recipeCode);
}

- (void)promotePreview {
    __block AppliedRecipeStep* mySelf = self;
    [queue addOperationWithBlock:^(){
        [mySelf idempotentRenderResult];
        mySelf = nil;
      }];
}

- (void)cancel {
    [self cancelResult];
    [self cancelPreview];
    [self cancelThumbnail];
    [renderer cancel];
}

- (UIImage*)currentPreviewAtFullStrength {
    [self idempotentRenderPreview];
    return _currentPreviewAtFullStrength;
}

- (UIImage*)currentThumbAtCurrentStrength {
    [self idempotentRenderThumbnail];
    return _currentThumbAtCurrentStrength;
}

- (UIImage*)sourcePreview {
    AppliedRecipeStep* prev = self.previousStep;
    if (prev)
        return prev.resultPreview;
    return _sourcePreview;
}

- (UIImage*)sourceThumb {
    AppliedRecipeStep* prev = self.previousStep;
    if (prev)
        return prev.currentThumbAtCurrentStrength;
    return _sourceThumb;
}

- (UIImage*)resultPreview {
    [self idempotentRenderResult];
    return _resultPreview;
}

- (UIImage*)renderPreviewNoCrop:(UIImage *)srcImage {
    NSString* fullCode = [self accumulatedRecipeCode];
    DDLogInfo(@"renderPreviewNoCrop begin \"%@\"", fullCode);

    NSString* key = [NSString stringWithFormat:@"nocrop/%@", fullCode];
    UIImage* result = [self.parent.previewCache objectForKey:key];
    if (!result) {
        NSAssert(srcImage, @"renderPreviewNoCrop got no srcImage");
        result = applyRecipeToUIImage(fullCode, srcImage, masterSize);
        [self.parent.previewCache setObject:result forKey:key];
    }
    DDLogInfo(@"renderPreviewNoCrop end \"%@\" (%.1f %.1f)", fullCode,
      result.size.width, result.size.height);

    if (!result)
        DDLogWarn(@"renderPreviewNoCrop returning nil");
    return result;
}

+ (NSString*)recipeCode:(NSString*)code withStrength:(NSUInteger)strength {
    NSString* result = code;
    if (strength != 100) {
        if (![TRRecipe isAtomic:result]) {
            result = [[@"(" stringByAppendingString:result] stringByAppendingString:@")"];
        }
        if (strength % 10 == 0) {
            result = [result stringByAppendingFormat:@"%zd", strength / 10];
        } else {
            result = [result stringByAppendingFormat:@"%02zd", strength];
        }
    }
    return result;
}

- (NSString*)accumulatedRecipeCode {
    AppliedRecipeStep* prev = self.previousStep;
    if (prev)
        return [prev.accumulatedRecipeCode stringByAppendingString:_recipeCode];
    else
        return _recipeCode;
}

- (NSString*)prefixRecipeCode {
    AppliedRecipeStep* prev = self.previousStep;
    if (prev)
        return [prev accumulatedRecipeCode];
    return @"";
}

- (NSString*)cumulativeRecipeCode {
    return self.accumulatedRecipeCode;
}

- (void)purgeThumbnails {
    DDLogInfo(@"purgeThumbnails %@", [self accumulatedRecipeCode]);
    [renderer cancel];
    [renderer purge];
}

- (void)releaseMemoryForNonVisibleStep {
    [self purgeThumbnails];
    renderer = nil;
}

- (void)releaseMemoryForEditView {
    DDLogInfo(@"AppliedRecipeStep releaseMemoryForEditView %@", [self accumulatedRecipeCode]);
    [self cancelResult];
    [self purgeThumbnails];
    renderer = nil;

    [resultPreviewLock lock];
    _resultPreview = nil;
    [resultPreviewLock unlockWithCondition:0];

    AppliedRecipeStep* prev = self.previousStep;

    [currentPreviewLock lock];
    _currentPreviewAtFullStrength = nil;
    if (prev)
        _sourcePreview = nil;
    [currentPreviewLock unlockWithCondition:0];

    [currentThumbLock lock];
    _currentThumbAtCurrentStrength = nil;
    if (prev)
        _sourceThumb = nil;
    [currentThumbLock unlockWithCondition:0];
}

- (UIImage*)thumbnailForCode:(NSString*)code {
    DDLogVerbose(@"thumbnailForCode %@", code);
    return [renderer thumbnailForCode:code step:self];
}

- (NSString*)baseCode {
    return _baseCode;
}

- (NSNumber*)strength {
    return _strength;
}

- (NSString*)recipeCode {
    return _recipeCode;
}

- (NSArray*)visibleCodes {
    @synchronized (self) {
        return _visibleCodes;
    }
}

- (void)setVisibleCodes:(NSArray*)visibleCodes {
    @synchronized (self) {
        _visibleCodes = visibleCodes;
    }
}

- (NSArray*)allRecipeCodes {
    AppliedRecipeStep* prev = self.previousStep;
    if (!prev) {
        @synchronized (self) {
            return _allRecipeCodes;
        }
    } else {
        return prev.allRecipeCodes;
    }
}

- (void)setAllRecipeCodes:(NSArray*)allRecipeCodes {
    // make a deep copy
    NSMutableArray* all = [[NSMutableArray alloc] initWithCapacity:allRecipeCodes.count];
    for (NSArray* a in allRecipeCodes)
        [all addObject:[[NSArray alloc] initWithArray:a copyItems:YES]];

    @synchronized (self) {
        _allRecipeCodes = all;
    }
}
@end
