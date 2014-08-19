#import <CoreGraphics/CoreGraphics.h>

// Helpful definition for general use in TR code (and consumers thereof)
#ifndef TRUNUSED
#define TRUNUSED __attribute__((unused))
#endif

static const BOOL wantDebugStyletList = NO;

// A Recipe is a code describing a sequence of Stylets (and strengths) to apply.
// The applyToCGImage method runs that sequence on a given input image.

@interface TRRecipe: NSObject
@property (atomic, copy) NSString* code;

- (TRRecipe*) initWithCode:(NSString*)recipeCode;
- (void) append:(NSString*)recipeCode;
- (CGImageRef) applyToCGImage:(CGImageRef)image masterSize:(CGSize)masterSize
  CF_RETURNS_RETAINED;
- (CGImageRef) consumeCGImage:(CGImageRef) CF_CONSUMED image masterSize:(CGSize)masterSize
  CF_RETURNS_RETAINED;

+ (void)purgeCaches;

+ (NSString*) nameForRecipeCode:(NSString*)code;
+ (BOOL) isBuiltin:(NSString*)code;
+ (BOOL) isAtomic:(NSString*)code;
+ (NSArray*) styletLibrary;
+ (NSDictionary*) historicalStyletLibraries;
+ (NSArray*) namedRecipes;
+ (NSArray*) historyListOfSize:(NSUInteger)size;
+ (NSArray*) magicList;
+ (NSString*) normalizedRecipeCode:(NSString*)code;
+ (NSArray*) styletsInRecipeCode:(NSString*)code;
@end

@interface TRRecipeCodeTokenizer : NSObject
- (TRRecipeCodeTokenizer*) initWithCode:(NSString*)code;
- (id) next;
@end

@interface TRRecipeNode: NSObject;
- (void) normalize;
@end

@interface TRRecipeCodeParser : NSObject
- (TRRecipeCodeParser*) initWithCode:(NSString*)code;
- (TRRecipeNode*) tree;
@end

@interface TRRecipeDumper : NSObject
- (TRRecipeDumper*) initWithCode:(NSString*)code;
- (TRRecipeDumper*) initWithTree:(TRRecipeNode*)tree;
- (NSString*) description;
@end