//
//  ImageDataController.h
//  RadLab
//
//  Created by Geoff Scott on 10/29/12.
//  Copyright (c) 2012 Totally Rad. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AppliedRecipeStep.h"
#import "TRImageProvider.h"

typedef enum {
    kStyletFolderIDMagic = 0,
    kStyletFolderIDRecipes = 1,
    kStyletFolderIDHistory = 2,
    kStyletFolderIDLibrary = 3,
    kStyletFolderIDStore = 4,
} StyletFolderID;

typedef enum {
    kStyletCellType = 0,
    kRecipeCellType,
    kLockedFacebookCellType,
    kLockedTwitterCellType,
    kLockedInstagramCellType,
    kLockedMailingListCellType
} ThumbnailCellType;

static NSString* const kNotificationThumbnailCodeRendered = @"kNotificationThumbnailCodeRendered";
static NSString* const kNotificationThumbnailIndexRendered = @"kNotificationThumbnailIndexRendered";
static NSString* const kNotificationRecipeImported = @"kNotificationRecipeImported";
static NSString* const kNotificationResetStyletSections = @"kNotificationResetStyletSections";

@class ThumbnailAttributes;
@class ChooseImageViewController;
@class EditGridViewController;
@class ShareViewController;

@interface ImageDataController : NSObject

// Run various stress tests for thumbnail rendering, etc.
- (void)selfTest;

// Setup the image provider.  An image provider encapsulates various methods
// of acquiring image data, hiding differences between the camera, inter-app
// handoff, pasteboard, camera roll (asset library) etc.
- (void)setImageProvider:(id<TRImageProvider>)provider;
- (void)applyTools;

- (void)setThumbnailPresentationSize:(CGSize)sz;
- (void)setPreviewPresentationSize:(CGSize)sz;

// Inform ImageDataController that a request for currentLarge (and other
// resized images) may be forthcoming soon.  The "Share" view calls this
// so the large image will be ready for Facebook sharing if needed.
- (void)startResizingForShareView;

// Inform the ImageDataController that we're leaving the Edit view and can
// quit rendering thumbnails for the grid.
- (void)editViewWillAppear;
- (void)editViewWillDisappear;
- (void)rebuildCurrentThumbnails;
- (void)editViewNowShowingSections:(NSArray*)sections
  andIndexPaths:(NSArray*)indexPaths;

// The FullRez (full-resolution) image is the image exactly as it comes from
// whatever source provided it (e.g. Camera Roll, Pasteboard, App sharing, etc).
@property (atomic, readonly) BOOL hasMaster;
@property (atomic, readonly) NSDictionary* masterMetadata;

// Master images: scaled versions of master
// The preview image is scaled to device screen size.
// The thumb image is cropped square and scaled to roughly 200x200.
@property (atomic, readonly) UIImage* masterPreview;
@property (atomic, readonly) UIImage* masterThumb;

// Current images are versions of the masters with the current recipe applied.
@property (atomic, readonly) UIImage* currentPreviewAtFullStrength;
@property (atomic, readonly) UIImage* currentPreviewAtCurrentStrength;
@property (atomic, readonly) UIImage* currentThumbAtCurrentStrength;

// The "original" preview has no crop/rotation applied
@property (atomic, readonly) UIImage* originalPreview;

// The "original" preview with filters applied with no crop/rotation applied
@property (atomic, readonly) UIImage* currentPreviewNoCrop;

// The "current large" image (and "master large" for that matter) are initiated
// via calling the startSpeculativeResizing method.
@property (nonatomic, readonly) UIImage* currentLarge;
@property (atomic, readonly) BOOL currentLargeIsReady;
typedef void (^WaitBlock)(void);
typedef void (^UIImageCompletionBlock)(UIImage*);
- (void)currentLargeWithWaitBlock:(WaitBlock)waitBlock
  completionBlock:(UIImageCompletionBlock)completionBlock;

// Previous images are results of the recipe up through the penultimate step.
// These are used for alpha-blending when adjusting the strength slider.
@property (atomic, readonly) UIImage* previousPreview;
@property (atomic, readonly) UIImage* previousThumb;

// The final full resolution image with the recipe applied. This is EXPENSIVE!
// In general, you can probably use the currentLarge image (above) for most
// purposes.  The currentLarge image size is larger than both Facebook and
// Instagram's image size limit.  You probably only need the finalFullRez image
// when saving to the camera roll.
@property (atomic, readonly) UIImage* finalFullRez;

// Adjusted (read and write) by the UI strength slider
@property (readwrite) NSNumber* currentStrength;

// The image orientation used as part of the crop process
@property (nonatomic, assign) UIImageOrientation cropImageOrientation;

// The rect size used to create the image & crop transforms
@property (nonatomic, assign) CGSize cropSourceImageSize;

// The transform to apply to the crop before image processing
@property (nonatomic, assign) CGAffineTransform cropTransform;

// Aspect Ratio of the crop area before the transform is applied
@property (nonatomic, assign) CGFloat cropAspectRatio;

// The number of Stylets in the thumbnail grid
- (NSUInteger)styletCountInSection:(NSInteger)section;

// The number of steps in the accumulating recipe
@property (readonly) NSUInteger appliedStepsCount;

// The currently displayed step of the accumulating recipe.  This may differ
// from appliedStepsCount when Undo/Redo is in use.
@property (readonly) NSInteger currentStepIndex;

// A code that may be used to reconstruct the Recipe
@property (readonly) NSString* recipeCode;

// array of delegates that display data
@property (nonatomic, copy) NSMutableArray *displayDelegates;

@property (readonly) NSCache* thumbnailCache;
@property (readonly) NSCache* previewCache;
- (void) purgeCaches;

@property (readonly) BOOL currentFilterChainIsViableAsRecipe;
@property (readonly) BOOL hasFiltersApplied;

// for use on iPad when no image has been selected by the user yet
@property (atomic, readonly) BOOL hasEmptyMaster;
- (void) setEmptyImageProvider;

- (BOOL)isControllerSetup;
- (void)setupController;
- (BOOL)loadStyletList;
- (BOOL)saveStyletList;
- (void)resetStyletList;
- (void)resetRecipe;
- (void)resetAppliedTools;

- (void)releaseMemoryForEditView;
- (void)releaseMemoryForShareView:(ShareViewController*)controller;
- (void)releaseMemoryForAllButChooseView:(ChooseImageViewController*)controller;

- (void)deleteAllRecipes;
- (void)deleteAllHistory;
- (void)resetMagic;
- (void)resetAllRecipesInAllFolders;
- (void)resetUnlockedFilters;
- (BOOL)hasRecipesOrHistoryOrMagic;

- (ThumbnailAttributes*)styletAttributesAtIndexPath:(NSIndexPath*)indexPath;
- (UIImage*)styletThumbnailAtIndexPath:(NSIndexPath*)indexPath;
- (void)moveStyletAtIndexPath:(NSIndexPath*)srcIndexPath toIndexPath:(NSIndexPath*)destIndexPath;

- (void)applyStyletWithIndexPath:(NSIndexPath*)indexPath;
- (BOOL)undoAppliedStylet;
- (BOOL)redoAppliedStylet;
- (void)pruneRedoState;

- (void)saveRecipeToHistory;
- (void)updateMagicWeights;

- (void)saveRecipeUsingName:(NSString*)name;
- (void)deleteRecipeAtIndexPath:(NSIndexPath*)indexPath;
- (BOOL)renameRecipeAtIndexPath:(NSIndexPath*)indexPath toName:(NSString*)newName;

- (BOOL)crashedOnPreviousRun;
- (void)ignorePreviousCrash;

- (NSString*)importRecipeFromURL:(NSURL*)url;
- (void)importRecipeBatch:(NSString*)recipeBatch;

// return YES if recipe added or recipe name changed (i.e. reload grid)
- (BOOL)assignRecipeName:(NSString*)name atIndexPath:(NSIndexPath*)indexPath;

- (UIImage*)thumbnailForRecipeStep:(NSUInteger)stepNumber;
- (ThumbnailAttributes*)styletAttributesForRecipeStep:(NSUInteger)stepNumber;

- (void)didShareToDestination:(NSString*)destination;
- (BOOL)hasSharedToDestination:(NSString*)destination;

- (void)unlockRecipeCodeAndFollowURL:(NSString*)recipeCode;

- (void)addStylet:(NSString*)strNewStylet;

@end

@interface ThumbnailAttributes : NSObject
@property (readonly, strong) NSString* code;
@property (readonly) NSURL* codeURL;
@property (readonly, strong) NSString* name;
@property (readonly, strong) NSString* namedRecipeName;
@property (readonly) ThumbnailCellType type;
@property (readonly) NSInteger strength; // 0..100
@property (readonly) BOOL isLocked;
@end