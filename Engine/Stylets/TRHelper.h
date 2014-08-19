@interface TRHelper : NSObject
+ (CGImageRef) blendFrom:(CGImageRef)bg to:(CGImageRef)fg
  strength:(float)strength CF_RETURNS_RETAINED;

// Create a CIContext with correct color space and dimensions
+ (CIContext*) getCIContext;

// Return a CIContext to a cache for reuse
+ (void) doneWithCIContext:(CIContext*)context;

+ (void) blockCoreImageUsage;
+ (void) unblockCoreImageUsage;
@end

