//
//  TRImageProvider.m
//  RadLab
//
//  Created by Tim Ruddick on 12/18/12.
//  Copyright (c) 2012 Totally Rad. All rights reserved.
//

#import "TRImageProvider.h"
#import "TRHelper.h"
#import "UIImage+Resize.h"
#import "CIContext+SingleThreadedRendering.h"
#import <ImageIO/ImageIO.h>
#import "UICommon.h"

static int ddLogLevel = LOG_LEVEL_INFO;

NSDictionary* metadataFromJPEGRepresentation(NSData* jpeg) {
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)jpeg, NULL);
    CFDictionaryRef metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, NULL);
    NSDictionary* result = CFBridgingRelease(metadata);
    CFRelease(source);
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

static CGSize absSize(CGSize sz) {
    return CGSizeMake(fabs(sz.width), fabs(sz.height));
}

// ----------------------------------------------------------------------

@interface TRAssetLibraryImageProvider () {
@private
    UIImage* full;
    NSConditionLock* fullLock;
    UIImage* preview;
    NSConditionLock* previewLock;
    CGSize _fullDimensions;
    ALAssetsLibrary* _assetsLibrary;
    ALAssetRepresentation* _assetRep;
    NSConditionLock* loadURLLock;
    NSOperationQueue* queue;
    NSDictionary* _metadata;
    NSURL* _assetURL;
}
@end

@implementation TRAssetLibraryImageProvider

- (void)dealloc {
    DDLogInfo(@"TRAssetLibraryImageProvider dealloc %@", self);
    [queue cancelAllOperations];
    [queue waitUntilAllOperationsAreFinished];
    [fullLock lock];
    full = nil;
    [fullLock unlockWithCondition:1];
    [previewLock lock];
    preview = nil;
    [previewLock unlockWithCondition:1];
    fullLock = nil;
    previewLock = nil;
    _assetsLibrary = nil;
    _assetRep = nil;
    loadURLLock = nil;
    queue = nil;
    _metadata = nil;
    _assetURL = nil;
}

- (CGImageRef)imageWithAdjustmentsApplied:(CGImageRef)img
  adjustments:(NSString*)adjustmentXMP CF_RETURNS_RETAINED {

    CGSize sz = CGSizeMake(CGImageGetWidth(img), CGImageGetHeight(img));
    CGRect rect = CGRectMake(0, 0, sz.width, sz.height);

    CIImage* ciImg = [CIImage imageWithCGImage:img];
    NSAssert(ciImg, @"TRAssetLibraryImageProvider imageWithAdjustmentsApplied imageWithCGImage:img is nil");

    NSError* error = nil;
    NSData* adjustmentData = [adjustmentXMP dataUsingEncoding:NSUTF8StringEncoding];
    if (LOG_VERBOSE) {
        NSString* adjustmentString = [[NSString alloc] initWithData:adjustmentData encoding:NSUTF8StringEncoding];
        DDLogInfo(@"adjustmentString: %@", adjustmentString);
    }
    NSArray* adjustments = [CIFilter filterArrayFromSerializedXMP:adjustmentData
      inputImageExtent:rect error:&error];
    if (error)
        DDLogError(@"error getting filter array: %@", error);

    for (CIFilter* adjustment in adjustments) {
        NSAssert(adjustment, @"TRAssetLibraryImageProvider imageWithAdjustmentsApplied adjustment is nil");
        [adjustment setValue:ciImg forKey:@"inputImage"];
        DDLogInfo(@"applying %@", adjustment);
        ciImg = adjustment.outputImage;
        NSAssert(ciImg, @"TRAssetLibraryImageProvider imageWithAdjustmentsApplied adjustment.outputImage is nil");
    }

    CIContext* ctx = [TRHelper getCIContext];
    CGImageRef result = [ctx createCGImageMoreSafely:ciImg fromRect:ciImg.extent];
    NSAssert(result, @"TRAssetLibraryImageProvider imageWithAdjustmentsApplied result is nil");
    [TRHelper doneWithCIContext:ctx];
    ctx = nil;

    DDLogInfo(@"finished applying adjustments; resulting size is %.1fx%.1f",
      ciImg.extent.size.width, ciImg.extent.size.height);
    return result;
}

- (id)init {
    self = [super init];
    if (self) {
        full = nil;
        preview = nil;
        fullLock = [[NSConditionLock alloc] initWithCondition:0];
        previewLock = [[NSConditionLock alloc] initWithCondition:0];
        queue = [[NSOperationQueue alloc] init];
        _assetsLibrary = [[ALAssetsLibrary alloc] init];
    }
    return self;
}

- (void)finishInitializing {
    [loadURLLock lockWhenCondition:1];
    [loadURLLock unlock];

    @autoreleasepool {
        _fullDimensions = _assetRep.dimensions;
      #if 1
        _assetURL = [_assetRep.url copy];

        NSMutableDictionary* meta = [_assetRep.metadata mutableCopy];

        [[meta objectForKey:@"{Exif}"] removeObjectsForKeys:[NSArray arrayWithObjects:
          @"PixelXDimension", @"PixelYDimension", @"SubjectArea", nil]];
        [[meta objectForKey:@"{TIFF}"] setValue:[NSNumber numberWithInt:UIImageOrientationUp] forKey:@"Orientation"];
        [meta removeObjectsForKeys:[NSArray arrayWithObjects:
          @"PixelHeight", @"PixelWidth", nil]];
        [meta setValue:[NSNumber numberWithInt:UIImageOrientationUp] forKey:@"Orientation"];

        _metadata = meta;
      #else
        DDLogError@"### FIXME: not cacheing metadata in TRAssetLibraryImageProvider");
        _metadata = [[NSMutableDictionary alloc] init];
      #endif
    }

    {
        __block TRAssetLibraryImageProvider* mySelf = self;
        NSOperation* op = [NSBlockOperation blockOperationWithBlock:^(){
            [mySelf idempotentRenderPreview];
          }];
        op.completionBlock = ^(){ mySelf = nil; };
        [queue addOperation:op];
    }
    if (0) {
        __block TRAssetLibraryImageProvider* mySelf = self;
        NSOperation* op = [NSBlockOperation blockOperationWithBlock:^(){
            [mySelf idempotentRenderFull];
          }];
        op.completionBlock = ^(){ mySelf = nil; };
        [queue addOperation:op];
    }
}

/*
- (id)initWithAssetRepresentation:(ALAssetRepresentation*)rep {
    self = [self init];
    if (self) {
        loadURLLock = [[NSConditionLock alloc] initWithCondition:1];
        _assetRep = rep;
        [self finishInitializing];
    }
    return self;
}
*/

- (id)initWithAssetURL:(NSURL*)assetURL {
    self = [self init];
    if (self) {
        loadURLLock = [[NSConditionLock alloc] initWithCondition:0];
        NSOperation* loadURLJob = [NSBlockOperation blockOperationWithBlock:^(void){
            [_assetsLibrary assetForURL:assetURL
              resultBlock:^(ALAsset* asset){
                self->_assetRep = [asset defaultRepresentation];
                [loadURLLock lockWhenCondition:0];
                [loadURLLock unlockWithCondition:1];
              } failureBlock:^(NSError* error){
                DDLogError(@"initWithAssetURL failed!");
                [loadURLLock lockWhenCondition:0];
                [loadURLLock unlockWithCondition:1];
              }];
        }];
        [queue addOperation:loadURLJob];
        [self finishInitializing];
    }
    return self;
}

- (void)idempotentRenderFull {
    __block ALAssetRepresentation* aRep = _assetRep;
    doOnce(fullLock, ^(){
        UIImage* f = nil;
        NSString* adjustmentXMP = [aRep.metadata objectForKey:@"AdjustmentXMP"];
        if (adjustmentXMP) {
            CGImageRef img = [self imageWithAdjustmentsApplied:aRep.fullResolutionImage adjustments:adjustmentXMP];
            f = [UIImage imageWithCGImage:img
              scale:aRep.scale orientation:aRep.orientation];
            CGImageRelease(img);
            adjustmentXMP = nil;
        } else {
            f = [UIImage imageWithCGImage:aRep.fullResolutionImage
              scale:aRep.scale orientation:aRep.orientation];
        }
        full = f;
        aRep = nil;
    });
}

- (void)idempotentRenderPreview {
    doOnce(previewLock, ^(){
        UIImage* p = [UIImage imageWithCGImage:_assetRep.fullScreenImage
          scale:_assetRep.scale orientation:UIImageOrientationUp];
        preview = p;
    });
}

- (UIImage*)fullSizeImage {
    [self idempotentRenderFull];

    UIImage* result = nil;
    [fullLock lockWhenCondition:1];
    result = full;
    full = nil;
    [fullLock unlockWithCondition:0];

    return result;
}

- (UIImage*)previewSizeImage {
    [self idempotentRenderPreview];

    UIImage* result = nil;
    [previewLock lockWhenCondition:1];
    result = preview;
    preview = nil;
    [previewLock unlockWithCondition:0];

    return result;
}

- (CGSize)fullDimensions {
    return _fullDimensions;
}

- (CGSize)previewDimensions {
    UIImage* p = self.previewSizeImage;
    return p.size;
}

- (NSDictionary*)metadata {
    return _metadata;
}

- (NSURL*)assetURL {
    return _assetURL;
}

- (id<TRImageProvider>)originalProvider {
    return nil;
}

@end

// ----------------------------------------------------------------------

@interface TREncodedImageProvider () {
@private
    UIImage* full;
    NSConditionLock* fullLock;
    UIImage* preview;
    NSConditionLock* previewLock;
    NSData* _encodedData;
    NSOperationQueue* queue;
    NSDictionary* _metadata;
}
@end

@implementation TREncodedImageProvider
- (id)initWithData:(NSData*)encodedData {
    self = [super init];
    if (self) {
        _encodedData = encodedData;
        fullLock = [[NSConditionLock alloc] initWithCondition:0];
        previewLock = [[NSConditionLock alloc] initWithCondition:0];

        @autoreleasepool {
            NSMutableDictionary* meta = [metadataFromJPEGRepresentation(encodedData) mutableCopy];
            
            [[meta objectForKey:@"{Exif}"] removeObjectsForKeys:[NSArray arrayWithObjects:
              @"PixelXDimension", @"PixelYDimension", @"SubjectArea", nil]];
            [[meta objectForKey:@"{TIFF}"] setValue:[NSNumber numberWithInt:UIImageOrientationUp] forKey:@"Orientation"];
            [meta removeObjectsForKeys:[NSArray arrayWithObjects:
              @"PixelHeight", @"PixelWidth", nil]];
            [meta setValue:[NSNumber numberWithInt:UIImageOrientationUp] forKey:@"Orientation"];

            _metadata = meta;
            DDLogVerbose(@"metadata %@", _metadata);
        }

        queue = [[NSOperationQueue alloc] init];
        {
            __block TREncodedImageProvider* mySelf = self;
            NSOperation* op = [NSBlockOperation blockOperationWithBlock:^(){
                [mySelf idempotentRenderFull];
              }];
            op.completionBlock = ^(){ mySelf = nil; };
            [queue addOperation:op];
        }
        {
            __block TREncodedImageProvider* mySelf = self;
            NSOperation* op = [NSBlockOperation blockOperationWithBlock:^(){
                [mySelf idempotentRenderPreview];
              }];
            op.completionBlock = ^(){ mySelf = nil; };
            [queue addOperation:op];
        }
    }
    return self;
}

- (void)dealloc {
    [queue cancelAllOperations];
}

- (void)idempotentRenderFull {
    doOnce(fullLock, ^(){
        full = [UIImage imageWithData:_encodedData];
        _encodedData = nil;
    });
}

- (void)idempotentRenderPreview {
    doOnce(previewLock, ^(){
        UIImage* f = self.fullSizeImage;
        CGFloat scale = 1.0;
        CGFloat maxAxis = MAX(f.size.width, f.size.height);
        CGFloat screenMaxAxis = MAX(
          [UIScreen mainScreen].bounds.size.width,
          [UIScreen mainScreen].bounds.size.height);
        if (maxAxis <= screenMaxAxis) {
            preview = full;
        } else {
            scale = screenMaxAxis / maxAxis;
            CGSize sz = CGSizeMake(f.size.width * scale, f.size.height * scale);
            preview = [f resizedImage:sz interpolationQuality:kCGInterpolationMedium];
        }
    });
}

- (UIImage*)fullSizeImage {
    [self idempotentRenderFull];
    return full;
}

- (UIImage*)previewSizeImage {
    [self idempotentRenderPreview];
    return preview;
}

- (CGSize)fullDimensions {
    UIImage* f = self.fullSizeImage;
    return f.size;
}

- (CGSize)previewDimensions {
    UIImage* p = self.previewSizeImage;
    return p.size;
}
- (NSDictionary*)metadata {
    return _metadata;
}
- (NSURL*)assetURL {
    // images from the pasteboard don't have URLs
    return nil;
}
- (id<TRImageProvider>)originalProvider {
    return nil;
}

@end

// ----------------------------------------------------------------------

@interface TRUIImageProvider () {
@protected
    UIImage* full;
    UIImage* preview;
    NSConditionLock* previewLock;
    NSOperationQueue* queue;
    NSDictionary* _metadata;
    NSURL* _assetURL;
}
@end

@implementation TRUIImageProvider
- (id)initWithUIImage:(UIImage *)image metadata:(NSDictionary*)metadata {
    self = [super init];
    if (!self)
        return nil;

    full = image;
    previewLock = [[NSConditionLock alloc] initWithCondition:0];
    queue = [[NSOperationQueue alloc] init];

    @autoreleasepool {
        NSMutableDictionary* meta = [metadata mutableCopy];
        [[meta objectForKey:@"{Exif}"] removeObjectsForKeys:[NSArray arrayWithObjects:
          @"PixelXDimension", @"PixelYDimension", @"SubjectArea", nil]];
        [[meta objectForKey:@"{TIFF}"] setValue:[NSNumber numberWithInt:UIImageOrientationUp] forKey:@"Orientation"];
        [meta removeObjectsForKeys:[NSArray arrayWithObjects:
          @"PixelHeight", @"PixelWidth", nil]];
        [meta setValue:[NSNumber numberWithInt:UIImageOrientationUp] forKey:@"Orientation"];
        _metadata = meta;

        DDLogVerbose(@"metadata %@", _metadata);
    }

    {
        __block TRUIImageProvider* mySelf = self;
        [queue addOperationWithBlock:^(){
            [mySelf idempotentRenderPreview];
            mySelf = nil;
          }];
    }

    return self;
}

- (void)dealloc {
    [queue cancelAllOperations];
}

- (void)idempotentRenderPreview {
    doOnce(previewLock, ^(){
        UIImage* f = self.fullSizeImage;
        CGFloat scale = 1.0;
        CGFloat maxAxis = MAX(f.size.width, f.size.height);
        CGFloat screenMaxAxis = MAX(
          [UIScreen mainScreen].bounds.size.width,
          [UIScreen mainScreen].bounds.size.height);
        if (maxAxis <= screenMaxAxis) {
            preview = full;
        } else {
            scale = screenMaxAxis / maxAxis;
            CGSize sz = CGSizeMake(f.size.width * scale, f.size.height * scale);
            preview = [f resizedImage:sz interpolationQuality:kCGInterpolationMedium];
        }
    });
}

- (UIImage*)fullSizeImage {
    return full;
}

- (UIImage*)previewSizeImage {
    [self idempotentRenderPreview];
    return preview;
}

- (CGSize)fullDimensions {
    return full.size;
}

- (CGSize)previewDimensions {
    UIImage* p = self.previewSizeImage;
    return p.size;
}

- (NSDictionary*)metadata {
    return _metadata;
}

- (NSURL*)assetURL {
    [NSException raise:@"MissingMethod" format:@"expected subclass to implement assetURL"];
    return nil;
}
- (id<TRImageProvider>)originalProvider {
    return nil;
}

@end

// ----------------------------------------------------------------------

@interface TRCameraImageProvider (){
    NSConditionLock* saveToCameraRollLock;
}
@end

@implementation TRCameraImageProvider
- (id)initWithCameraImage:(UIImage*)image metadata:(NSDictionary*)metadata {
    self = [super initWithUIImage:image metadata:metadata];
    if (self) {
        saveToCameraRollLock = [[NSConditionLock alloc] initWithCondition:0];
        {
            __block TRCameraImageProvider* mySelf = self;
            NSOperation* op = [NSBlockOperation blockOperationWithBlock:^(){
                [mySelf idempotentSaveToCameraRoll];
              }];
            op.completionBlock = ^(){ mySelf = nil; };
            [queue addOperation:op];
        }
    }
    return self;
}

- (void)idempotentSaveToCameraRoll {
    doOnce(saveToCameraRollLock, ^(){
        // rotate to UP orientation
        UIImage* upImage = [full resizedImage:full.size interpolationQuality:kCGInterpolationNone];

        ALAssetsLibrary* al = [[ALAssetsLibrary alloc] init];
        [al writeImageToSavedPhotosAlbum:upImage.CGImage metadata:_metadata
          completionBlock:^(NSURL* assetURL, NSError* error){
              if (error)
                  DDLogError(@"writeImageToSavedPhotosAlbum failed %@", error);
              else
                  _assetURL = assetURL;
          }];
    });
}

- (NSURL*)assetURL {
    [self idempotentSaveToCameraRoll];
    return _assetURL;
}
@end

// ----------------------------------------------------------------------

@interface TRTransformedImageProvider (){
    UIImage* full;
    UIImage* preview;
    id<TRImageProvider> original;
    NSOperationQueue* queue;
    NSConditionLock* transformLargeLock;
    NSConditionLock* transformPreviewLock;

    CGSize previewSize;
    CGSize referenceImageSize;
    UIImageOrientation imageOrientation;
    CGFloat cropAspect;
    CGAffineTransform cropTransform;
}
@end

@implementation TRTransformedImageProvider
- (id)initWithProvider:(id<TRImageProvider>)provider
  previewSize:(CGSize)prvwSize
  referenceImageSize:(CGSize)refImageSize
  imageOrientation:(UIImageOrientation)orientation
  cropAspect:(CGFloat)cAspect
  cropTransform:(CGAffineTransform)cTrans
{
    self = [super init];
    if (self) {
        original = provider;

        previewSize = prvwSize;
        referenceImageSize = refImageSize;
        imageOrientation = orientation;
        cropAspect = cAspect;
        cropTransform = cTrans;

        DDLogInfo(@"referenceImageSize (%.3f %.3f)",
          referenceImageSize.width, referenceImageSize.height);
        DDLogInfo(@"cropTransform (%.3f %.3f; %.3f %.3f; %.3f %.3f) (rot %.1f, det %.1f)",
          cropTransform.a, cropTransform.b, cropTransform.c, cropTransform.d,
          cropTransform.tx, cropTransform.ty,
          radiansToDegrees(rotationFromTransform(cropTransform)),
          determinantFromTransform(cropTransform));
        DDLogInfo(@"cropAspect %.6f", cropAspect);

        queue = [[NSOperationQueue alloc] init];
        transformPreviewLock = [[NSConditionLock alloc] initWithCondition:0];
        transformLargeLock = [[NSConditionLock alloc] initWithCondition:0];
        {
            __block TRTransformedImageProvider* mySelf = self;
            NSOperation* op = [NSBlockOperation blockOperationWithBlock:^(){
                [mySelf idempotentTransformFull];
              }];
            op.completionBlock = ^(){ mySelf = nil; };
            [queue addOperation:op];
        }

        {
            __block TRTransformedImageProvider* mySelf = self;
            NSOperation* op = [NSBlockOperation blockOperationWithBlock:^(){
                [mySelf idempotentTransformPreview];
              }];
            op.completionBlock = ^(){ mySelf = nil; };
            [queue addOperation:op];
        }
    }
    return self;
}

CGAffineTransform transformFromOrientation(UIImageOrientation orientation) {
    CGFloat adjScaleX = 1.0, adjScaleY = 1.0;
    CGFloat adjAngle = 0.0;
    
    switch (orientation) {
    case UIImageOrientationUp:
        break;
    case UIImageOrientationUpMirrored:
        adjScaleX = -1.0;
        break;
    case UIImageOrientationDownMirrored:
        adjScaleY = -1.0;
        break;
    case UIImageOrientationDown:
        adjAngle = 180.0;
        break;
    case UIImageOrientationRight:
        adjAngle = 90.0;
        break;
    case UIImageOrientationRightMirrored:
        adjAngle = -90.0;
        adjScaleY = -1;
        break;
    case UIImageOrientationLeft:
        adjAngle = -90.0;
        break;
    case UIImageOrientationLeftMirrored:
        adjAngle = 90.0;
        adjScaleY = -1;
        break;
    }

    return CGAffineTransformScale(
      CGAffineTransformRotate(CGAffineTransformIdentity, degreesToRadians(adjAngle)),
      adjScaleX, adjScaleY);
}

CGSize swapDimensions(CGSize sz) {
    return CGSizeMake(sz.height, sz.width);
}

CGSize correctDimensionsForOrientation(CGSize sz, UIImageOrientation orient) {
    switch (orient) {
    case UIImageOrientationRight:
    case UIImageOrientationRightMirrored:
    case UIImageOrientationLeft:
    case UIImageOrientationLeftMirrored:
        return swapDimensions(sz);
    default:
        return sz;
    }
}

- (CGSize)cropResultSizeForSourceSize:(CGSize)size {
    CGSize cropScale = CGSizeMake(
      xscaleFromTransform(cropTransform), yscaleFromTransform(cropTransform));
    CGRect cropRect = adjustRectToAspectRatio(
      CGRectMake(0, 0, size.width, size.height), cropAspect);
    CGSize result = CGSizeMake(cropScale.width * cropRect.size.width,
      cropScale.height * cropRect.size.height);

    result = correctDimensionsForOrientation(result, imageOrientation);

    return result;
}

- (UIImage*)crop:(UIImage*)sourceImage {
    CGSize resultSize = absSize([self cropResultSizeForSourceSize:sourceImage.size]);
    DDLogInfo(@"sourceSize (%.1f %.1f) %zd; resultSize (%.1f %.1f)",
      sourceImage.size.width, sourceImage.size.height, sourceImage.imageOrientation,
      resultSize.width, resultSize.height);
    CGRect cropRect = adjustRectToAspectRatioWithOrientation(
      CGRectMake(0, 0, referenceImageSize.width, referenceImageSize.height),
      cropAspect, imageOrientation);
    DDLogInfo(@"cropRect (%.1f %.1f; %.1f %.1f)",
      cropRect.origin.x, cropRect.origin.y,
      cropRect.size.width, cropRect.size.height);
    CGSize refSize = correctDimensionsForOrientation(referenceImageSize, imageOrientation);
    DDLogInfo(@"refSize (%.1f %.1f) %zd", refSize.width, refSize.height, imageOrientation);

    UIGraphicsBeginImageContextWithOptions(resultSize, NO, 1.0);

    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextScaleCTM(ctx, resultSize.width / cropRect.size.width,
      resultSize.height / cropRect.size.height);
    DDLogInfo(@"resultSize/cropRect (%.1f %.1f)",
      resultSize.width / cropRect.size.width,
      resultSize.height / cropRect.size.height);

    CGContextTranslateCTM(ctx, -cropRect.origin.x, -cropRect.origin.y);
    CGContextTranslateCTM(ctx, refSize.width / 2.0, refSize.height / 2.0);

    CGContextConcatCTM(ctx, CGAffineTransformInvert(cropTransform));

    CGAffineTransform orientTransform = transformFromOrientation(imageOrientation);
    CGContextConcatCTM(ctx, orientTransform);

    CGRect drawRect = CGRectMake(-refSize.width / 2.0, -refSize.height / 2.0,
      refSize.width, refSize.height);
    drawRect = CGRectApplyAffineTransform(drawRect, orientTransform);
    [sourceImage drawInRect:drawRect];

    UIImage* result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    NSAssert(result, @"TRTransformedImageProvider crop result is nil");

    DDLogInfo(@"crop result (%.1f %.1f)", result.size.width, result.size.height);
    return result;
}

- (void)idempotentTransformPreview {
    doOnce(transformPreviewLock, ^(){
        UIImage* img = [self fullSizeImage];
        CGFloat maxAxis = MAX(img.size.width, img.size.height);
        CGFloat previewSquareSize = MAX(previewSize.width, previewSize.height);
        CGFloat scale = previewSquareSize / maxAxis;
        CGSize resultSize = CGSizeMake(img.size.width * scale, img.size.height * scale);
        preview = [img resizedImage:resultSize interpolationQuality:kCGInterpolationMedium];
        CGSize sz = preview.size;
        DDLogInfo(@"preview size result (%.1f %.1f) %zd", sz.width, sz.height, preview.imageOrientation);
    });
}

- (void)idempotentTransformFull {
    doOnce(transformLargeLock, ^(){
        full = [self crop:original.fullSizeImage];
        CGSize sz = full.size;
        DDLogInfo(@"full size result (%.1f %.1f) %zd", sz.width, sz.height, full.imageOrientation);
        NSAssert(full.imageOrientation == UIImageOrientationUp,
          @"actual orientation %zd", full.imageOrientation);
    });
}

- (id<TRImageProvider>)originalProvider {
    return original;
}

- (UIImage*)fullSizeImage {
    [self idempotentTransformFull];
    return full;
}

- (UIImage*)previewSizeImage {
    [self idempotentTransformPreview];
    DDLogInfo(@"transformed preview %@ (%.1f %.1f)", preview,
      preview.size.width, preview.size.height);
    return preview;
}

- (CGSize)fullDimensions {
    CGSize result = absSize([self cropResultSizeForSourceSize:original.fullDimensions]);
    DDLogInfo(@"fullDimensions (%.1f %.1f)", result.width, result.height);
    return result;
}

- (CGSize)previewDimensions {
    CGSize result = absSize([self cropResultSizeForSourceSize:original.previewDimensions]);
    DDLogInfo(@"previewDimensions (%.1f %.1f)", result.width, result.height);
    return result;
}

- (NSDictionary*)metadata {
    return original.metadata; // TODO (dimensions?)
}

- (NSURL*)assetURL {
    return original.assetURL; // TODO
}
@end