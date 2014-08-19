//
//  TRImageProvider.h
//  RadLab
//
//  Created by Tim Ruddick on 12/18/12.
//  Copyright (c) 2012 Totally Rad. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AssetsLibrary/AssetsLibrary.h>

// Encapsulate image sources (such as ALAssetRepresentation) that can provide
// small (preview size) images quickly, and full size images with some effort.
@protocol TRImageProvider <NSObject>
@required
- (UIImage*)previewSizeImage;
- (UIImage*)fullSizeImage;
- (CGSize)previewDimensions;
- (CGSize)fullDimensions;
- (NSDictionary*)metadata;
- (NSURL*)assetURL;
- (id<TRImageProvider>)originalProvider;
@end

// Initialize with an ALAssetRepresentation
@interface TRAssetLibraryImageProvider : NSObject <TRImageProvider> 
//- (id)initWithAssetRepresentation:(ALAssetRepresentation*)asset;
- (id)initWithAssetURL:(NSURL*)assetURL;
@end

// Initialize with encoded JPEG or PNG data
@interface TREncodedImageProvider : NSObject <TRImageProvider> 
- (id)initWithData:(NSData*)encodedData;
@end

// Initialize with full-size UIImage (e.g. from Camera)
@interface TRUIImageProvider : NSObject <TRImageProvider>
- (id)initWithUIImage:(UIImage*)image metadata:(NSDictionary*)metadata;
@end

@interface TRCameraImageProvider : TRUIImageProvider
- (id)initWithCameraImage:(UIImage*)image metadata:(NSDictionary*)metadata;
@end

// Initialize with a TRImageProvider and crop/rotation transforms
@interface TRTransformedImageProvider : NSObject <TRImageProvider>
- (id)initWithProvider:(id<TRImageProvider>)provider
  previewSize:(CGSize)previewSize
  referenceImageSize:(CGSize)referenceImageSize
  imageOrientation:(UIImageOrientation)orientation
  cropAspect:(CGFloat)cropAspect
  cropTransform:(CGAffineTransform)cropTransform;
@end