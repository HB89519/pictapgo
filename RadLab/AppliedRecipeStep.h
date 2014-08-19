//
//  AppliedRecipeStep.h
//  RadLab
//
//  Created by Geoff Scott on 11/28/12.
//  Copyright (c) 2012 Totally Rad. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TRRecipe.h"

@class ImageDataController;

@interface AppliedRecipeStep : NSObject

+ (AppliedRecipeStep*)newFirstStepIn:(ImageDataController*)parent
  masterSize:(CGSize)masterSize preview:(UIImage*)preview thumb:(UIImage*)thumb
  allRecipeCodes:(NSArray*)allRecipeCodes;

// strength in range 0.0 to 100.0
- (AppliedRecipeStep*)newStepByApplyingRecipeCode:(NSString*)code
  withStrength:(NSNumber*)strength;

- (void)changePreview:(UIImage*)preview thumb:(UIImage*)thumb;

- (void)changePreviousStepTo:(AppliedRecipeStep*)newStep;

typedef void (^ThumbnailCompletionBlock)(void);
- (UIImage*)thumbnailForCode:(NSString*)code;

- (void)setVisibleCodes:(NSArray*)visibleCodes;

- (void)cancelSpeculativeThumbnails;
- (void)rebuildThumbnails;
- (void)promotePreview;
- (void)cancel;
- (void)releaseMemoryForNonVisibleStep;
- (void)releaseMemoryForEditView;

- (NSString*)cumulativeRecipeCode;
- (NSString*)baseCode;
- (NSNumber*)strength;
- (NSString*)recipeCode;
- (UIImage*)resultPreview;
- (UIImage*)renderPreviewNoCrop:(UIImage *)srcImage;
- (UIImage*)currentPreviewAtFullStrength;
- (UIImage*)currentThumbAtCurrentStrength;

- (void)setAllRecipeCodes:(NSArray*)allRecipeCodes;
- (AppliedRecipeStep*)previousStep;
@end
