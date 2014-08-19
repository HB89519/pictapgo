#import "TRFilter.h"
#include <iostream>

static int ddLogLevel = LOG_LEVEL_INFO;

#define LAB_CUBE_SIZE 8

struct XYZ { float x, y, z; };
struct RGBPrime { float rp, gp, bp; };
struct XYZPrime { float xp, yp, zp; };
struct XYZDoublePrime { float xpp, ypp, zpp; };
struct LAB { float L, a, b; };

#define SRGB_XYZ_CUTOFF_CONSTANT 0.04045f
#define SRGB_XYZ_ADDITION_CONSTANT 0.055f
#define SRGB_XYZ_GAMMA 2.4f
#define SRGB_XYZ_DIVISION_CONSTANT 12.92f

#define LAB_ONESIXTEEN 116
#define LAB_SIXTEEN 16

float rgbToRgbPrime(float colorVal) {
    if (colorVal > SRGB_XYZ_CUTOFF_CONSTANT) {
        return powf(((colorVal + SRGB_XYZ_ADDITION_CONSTANT) /
          (1.0 + SRGB_XYZ_ADDITION_CONSTANT)), SRGB_XYZ_GAMMA);
    } else {
        return colorVal / SRGB_XYZ_DIVISION_CONSTANT;
    }
}

XYZ calc_sRGB_D65(const RGBPrime& p) {
    XYZ v;
    v.x = p.rp * 0.4124564f + p.gp * 0.3575761f + p.bp * 0.1804375f;
    v.y = p.rp * 0.2126729f + p.gp * 0.7151522f + p.bp * 0.0721750f;
    v.z = p.rp * 0.0193339f + p.gp * 0.1191920f + p.bp * 0.9503041f;
    return v;
}

XYZPrime calc_CIE_Lab_D65(const XYZ& xyz) {
    XYZPrime v;
    v.xp = xyz.x / 0.95047f;
    v.yp = xyz.y / 1.0f;
    v.zp = xyz.z / 1.08883f;
    return v;
}

float xyzDoublePrime(float v) {
    if (v > 0.008856f) {
        return powf(v, 1.0f / 3.0f);
    } else {
        return (903.3f * v + LAB_SIXTEEN) / LAB_ONESIXTEEN;
    }
}

LAB labGrey(float src[4]) {
    // RGB to XYZ
    RGBPrime rgbP;
    rgbP.rp = rgbToRgbPrime(src[0]);
    rgbP.gp = rgbToRgbPrime(src[1]);
    rgbP.bp = rgbToRgbPrime(src[2]);

    XYZ xyz = calc_sRGB_D65(rgbP);

    // XYZ to CIE L*ab
    XYZPrime xyzP = calc_CIE_Lab_D65(xyz);

    XYZDoublePrime xyzPP;
    xyzPP.xpp = xyzDoublePrime(xyzP.xp);
    xyzPP.ypp = xyzDoublePrime(xyzP.yp);
    xyzPP.zpp = xyzDoublePrime(xyzP.zp);

    // a and b are both zero in greyscale, so we only need
    // yDoublePrime for calculating L
    LAB lab;
    lab.L = (LAB_ONESIXTEEN * xyzPP.ypp) - 16;

    // We don't actually care about a and b for greyscale conversion
    // lab.a = 500.0f * (xyzPP.xpp - xyzPP.ypp);
    // lab.b = 200.0f * (xyzPP.ypp - xyzPP.zpp);

    return lab;
}

static NSData* cube(size_t dimension) {
    const size_t size = dimension;
    const size_t cubeDataSize = size * size * size * sizeof(float) * 4;
    float* cubeData = (float*)malloc(cubeDataSize);

    float* p = cubeData;
    float ch[4] = {0, 0, 0, 1};
    for (size_t b = 0; b < size; ++b) {
        ch[2] = float(b) / float(size - 1);
        for (size_t g = 0; g < size; ++g) {
            ch[1] = float(g) / float(size - 1);
            for (size_t r = 0; r < size; ++r) {
                ch[0] = float(r) / float(size - 1);
                LAB lab = labGrey(ch);
                DDLogCVerbose(@"Lab for %f,%f,%f = %f", ch[0], ch[1], ch[2], lab.L);
                p[0] = p[1] = p[2] = lab.L / 100.0;
                p[3] = 1.0;
                p += 4;
            }
        }
    }

    NSData* data = [NSData dataWithBytesNoCopy:cubeData length:cubeDataSize
      freeWhenDone:YES];
    NSCAssert(data, @"TRLabGrey cube data is nil");
    return data;
}

@interface TRLabGrey_extras : NSObject {
    @package
    NSData* cubeData;
    int cubeSize;
}
@end

static TRLabGrey_extras* extras;

@implementation TRLabGrey_extras
+ (TRLabGrey_extras*) extrasManager {
    if (!extras)
        extras = [[super allocWithZone:NULL] init];
    return extras;
}
+ (id) allocWithZone:(NSZone*)zone {
    return [self extrasManager];
}
- (id) init {
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();

    cubeSize = LAB_CUBE_SIZE;
    cubeData = cube(cubeSize);

    CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    DDLogVerbose(@"TRLabGrey_extras init took %0.3f seconds", end - start);

    return self;
}
- (id) copyWithZone:(NSZone*)zone {
    return self;
}
@end

@implementation TRLabGrey
@synthesize inputImage;

- (id) init {
    [TRLabGrey_extras extrasManager];
    self = [super init];
    return self;
}

+ (TRLabGrey*) newWithInput:(CIImage*)inputImage {
    TRLabGrey* c = [[TRLabGrey alloc] init];
    NSAssert(c, @"TRLabGrey newWithInput c is nil");
    c.inputImage = inputImage;
    return c;
}

- (CIImage*) outputImage {
    DDLogVerbose(@"TRLabGrey outputImage");

    TRLabGrey_extras* extras = [TRLabGrey_extras extrasManager];

    CIFilter* cube = [CIFilter filterWithName:@"CIColorCube"];
    NSAssert(cube, @"TRLabGrey outputImage cube is nil");
    [cube setDefaults];
    [cube setValue:inputImage forKey:@"inputImage"];
    [cube setValue:extras->cubeData forKey:@"inputCubeData"];
    [cube setValue:[NSNumber numberWithInt:extras->cubeSize]
      forKey:@"inputCubeDimension"];

    CIImage* result = cube.outputImage;
    NSAssert(result, @"TRLabGrey outputImage result is nil");
    return result;
}

@end
