#import "TRFilter.h"
#import "TRHelper.h"
#import "CIContext+SingleThreadedRendering.h"

static int ddLogLevel = LOG_LEVEL_INFO;
static int MAX_CACHED_CONTEXTS = 2;

@interface ContextCache : NSObject {
@public
    NSMutableArray* cache;
}
@end

@implementation ContextCache
- (id)init {
    self = [super init];
    if (self) {
        cache = [[NSMutableArray alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver:self
          selector:@selector(didReceiveMemoryWarning:)
          name:UIApplicationDidReceiveMemoryWarningNotification
          object:nil];
    }
    return self;
}
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
- (void)didReceiveMemoryWarning:(NSNotification*)notification {
    @synchronized (self) {
        [cache removeAllObjects];
    }
}
@end

static ContextCache* contextCache;
static dispatch_once_t contextCacheOnce;

@implementation TRHelper
+ (CGImageRef) blendFrom:(CGImageRef)bg to:(CGImageRef)fg strength:(float)strength
  CF_RETURNS_RETAINED
{
    if (strength >= 0.99) {
        return CGImageRetain(fg);
    } else if (strength <= 0.01) {
        return CGImageRetain(bg);
    }

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGSize sz = CGSizeMake(CGImageGetWidth(bg), CGImageGetHeight(bg));
    CGContextRef cgc = CGBitmapContextCreate(nil, sz.width, sz.height,
      8, sz.width * 4, colorSpace, kCGImageAlphaNoneSkipLast);
    NSAssert(cgc, @"TRHelper blendFrom:to:strength cgc is nil");
    CGColorSpaceRelease(colorSpace);
    if (strength < 0.99) {
        CGContextDrawImage(cgc, CGRectMake(0, 0, sz.width, sz.height), bg);
    }
    if (strength > 0.01) {
        CGContextSetAlpha(cgc, strength);
        CGContextDrawImage(cgc, CGRectMake(0, 0, sz.width, sz.height), fg);
        CGContextSetAlpha(cgc, 1.0);
    }
    CGImageRef result = CGBitmapContextCreateImage(cgc);
    CGContextRelease(cgc);
    NSAssert(result, @"TRHelper blendFrom:to:strength result is nil");
    return result;
}

+ (CIContext*) getCIContext {
    DDLogVerbose(@"getCIContext");

    dispatch_once(&contextCacheOnce, ^(){
        contextCache = [[ContextCache alloc] init];
    });

    CIContext* context = nil;
    @synchronized (contextCache) {
        context = [contextCache->cache lastObject];
        if (context) {
            [contextCache->cache removeLastObject];
            return context;
        }
    }

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    NSDictionary* options = [NSDictionary dictionaryWithObjectsAndKeys:
      (__bridge id)colorSpace, kCIContextOutputColorSpace,
      (__bridge id)colorSpace, kCIContextWorkingColorSpace,
      [NSNumber numberWithBool:NO], kCIContextUseSoftwareRenderer,
      nil];

    context = [CIContext contextWithOptions:options];
    CGColorSpaceRelease(colorSpace);
    NSAssert(context, @"TRHelper getCIContext returning nil");

    DDLogVerbose(@"getCIContext returning %p", context);
    return context;
}

+ (void)doneWithCIContext:(CIContext*)context {
    DDLogVerbose(@"doneWithCIContext %p", context);

    @synchronized (contextCache) {
        if ([contextCache->cache count] < MAX_CACHED_CONTEXTS) {
            [contextCache->cache addObject:context];
        }
    }
    context = nil;
}

+ (void) blockCoreImageUsage {
    [CIContext blockCoreImageUsage];
}

+ (void) unblockCoreImageUsage {
    [CIContext unblockCoreImageUsage];
}

@end