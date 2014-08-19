//
//  ALAssetsLibrary category to handle a custom photo album
//
//  Created by Marin Todorov on 10/26/11.
//  Copyright (c) 2011 Marin Todorov. All rights reserved.
//
// Copyright (c) 2012-2013, Kjuly
//
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the "Software"),
// to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense,
// and/or sell copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
// DEALINGS IN THE SOFTWARE.


#import <Foundation/Foundation.h>
#import <AssetsLibrary/AssetsLibrary.h>

@interface ALAssetsLibrary (CustomPhotoAlbum)

//           |image|: the target image to be saved
//       |albumName|: custom album name
// |completionBlock|: block to be executed when succeed to write the image data
//                    to the assets library (camera roll)
//    |failureBlock|: block to be executed when failed to add the asset to the
//                    custom photo album
-(void)saveImage:(UIImage *)image
         toAlbum:(NSString *)albumName
 completionBlock:(ALAssetsLibraryWriteImageCompletionBlock)completionBlock
    failureBlock:(ALAssetsLibraryAccessFailureBlock)failureBlock;

//           |image|: the target image to be saved
//        |metadata|: image metadata
//       |albumName|: custom album name
// |completionBlock|: block to be executed when succeed to write the image data
//                    to the assets library (camera roll)
//    |failureBlock|: block to be executed when failed to add the asset to the
//                    custom photo album
-(void)saveImage:(UIImage *)image
        metadata:(NSDictionary *)metadata
         toAlbum:(NSString *)albumName
 completionBlock:(ALAssetsLibraryWriteImageCompletionBlock)completionBlock
    failureBlock:(ALAssetsLibraryAccessFailureBlock)failureBlock;

//        |videoUrl|: the target video to be saved
//       |albumName|: custom album name
// |completionBlock|: block to be executed when succeed to write the image data
//                    to the assets library (camera roll)
//    |failureBlock|: block to be executed when failed to add the asset to the
//                    custom photo album
-(void)saveVideo:(NSURL *)videoUrl
         toAlbum:(NSString *)albumName
 completionBlock:(ALAssetsLibraryWriteImageCompletionBlock)completionBlock
    failureBlock:(ALAssetsLibraryAccessFailureBlock)failureBlock;
@end
