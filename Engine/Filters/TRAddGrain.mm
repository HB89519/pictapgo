#import "TRFilter.h"
#import <CoreGraphics/CGImage.h>
#import "TinyMT/tinymt32.h"
#import "TRStylet.h"

@implementation TRAddGrain
@synthesize graininess;
@synthesize size;
@synthesize noiseMode;

namespace {
struct Randomness {
    Randomness() {
        // use the current time to seed the random number generator
        uint64_t timeNow = CFAbsoluteTimeGetCurrent() * 1000000;
        tinymt32_init(&tinymt, timeNow & 0xffffffff);
    }

    Randomness(int s1, int s2) {
        // Seed with x,y coordinates
        tinymt32_init(&tinymt, s1 + s2);
    }

    int32_t operator()() { return tinymt32_generate_uint32(&tinymt); }
    tinymt32_t tinymt;
};
}


+ (TRAddGrain*) newWithSize:(CGSize)size graininess:(NSNumber*)graininess {
    NSAssert(size.width > 0 && size.height > 0,
      @"%.1fx%.1f", size.width, size.height);

    TRAddGrain* result = [[TRAddGrain alloc] init];
    NSAssert(result, @"TRAddGrain newWithSize returned nil");
    result.graininess = graininess;
    result.size = size;
    result.noiseMode = kAddGrainGaussian;
    return result;
}

- (CIImage*) outputImage {
    static const size_t grainImageSize = 512;

    NSString* cacheKey =
      [NSString stringWithFormat:@"grain-%d-%.4f", noiseMode, graininess.floatValue];
    NSData* nbuf = [TRStylet preflightObjectForIdent:cacheKey];

    if (!nbuf) {
        static const uint32_t SCALE = 4096; // for fixed-point math scaling

        const float grainSize = graininess.floatValue *
          (noiseMode == kAddGrainGaussian ? 3.0f : 1.0f);
        const uint32_t strength = uint32_t(grainSize * SCALE);
        const uint32_t offset = uint32_t(255.0 * (0.5 - grainSize / 2) * SCALE);

        Randomness rnd;

        const size_t pixelcount = grainImageSize * grainImageSize;
        const size_t bufsize = pixelcount * 4;
        uint32_t* buf = (uint32_t*)malloc(bufsize);
        for (NSUInteger i = 0; i < pixelcount; ++i) {
            uint32_t v = rnd();
            if (noiseMode == kAddGrainGaussian) {
                v = (v & 0xff) + ((v & 0xff00) >> 8) +
                  ((v & 0xff0000) >> 16) + ((v & 0xff000000) >> 24);
                v /= 4;
            } else {
                v &= 0xff;
            }
            v = (v * strength + offset) / SCALE;
            buf[i] = (0xff | (v << 8) | (v << 16) | (v << 24));
        }

        nbuf = [[NSData alloc] initWithBytesNoCopy:buf length:bufsize
          freeWhenDone:YES];
        [TRStylet setPreflightObject:nbuf forIdent:cacheKey];
    }

    CGColorSpaceRef dRGB = CGColorSpaceCreateDeviceRGB();
    CIImage* random = [CIImage
      imageWithBitmapData:nbuf bytesPerRow:grainImageSize * 4
      size:CGSizeMake(grainImageSize, grainImageSize)
      format:kCIFormatARGB8 colorSpace:nil];
    CGColorSpaceRelease(dRGB);
    NSAssert(random, @"TRAddGrain outputImage random is nil");

    CIImage* scaled = random;
    if (grainImageSize != size.width || grainImageSize != size.height) {
        const CGFloat maxAxis = MAX(size.width, size.height);
        const CGFloat scale = maxAxis / grainImageSize;
        CGAffineTransform scaleTransform = CGAffineTransformMakeScale(scale, scale);
        scaled = [scaled imageByApplyingTransform:scaleTransform];
        NSAssert(scaled, @"TRAddGrain outputImage scaled is nil");

        CIFilter* crop = [CIFilter filterWithName:@"CICrop"];
        NSAssert(crop, @"TRAddGrain outputImage crop is nil");
        [crop setDefaults];
        [crop setValue:scaled forKey:@"inputImage"];
        [crop setValue:[CIVector vectorWithX:0 Y:0 Z:size.width W:size.height]
          forKey:@"inputRectangle"];
        
        scaled = crop.outputImage;
    }

    NSAssert(scaled, @"TRAddGrain outputImage scaled is nil");
    return scaled;
}

@end
