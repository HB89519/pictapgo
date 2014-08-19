#import "TRFilter.h"
#import "DDLog.h"
#include <iostream>

static int ddLogLevel = LOG_LEVEL_INFO;

using tr::util::Spline;

@implementation TRCurves
@synthesize inputImage;
@synthesize inputStrength;

static float lerp(float v1, float v2, float strength) {
    float result = v1 + (v2 - v1) * strength;
    return result;
}

static float clamp(float v) {
    return std::min<float>(1.0, std::max<float>(0.0, v));
}

static float brighten(float v1) {
    return 0.1 + 0.9 * v1;
}

+ (NSData*)newCubeDataForSize:(size_t)dimension strength:(float)strength
  spRGB:(Spline&)spRGB spR:(Spline&)spR spG:(Spline&)spG spB:(Spline&)spB {
    DDLogCVerbose(@"TRCurves cube strength %f", strength);
    const size_t size = dimension;
    const size_t cubeDataSize = size * size * size * sizeof(float) * 4;
    float* cubeData = (float*)malloc(cubeDataSize);

    float* p = cubeData;
    float ch[4] = {0, 0, 0, 1};
    for (size_t b = 0; b < size; ++b) {
        ch[2] = lerp(float(b) / float(size - 1),
          spRGB(spB(float(b) / float(size - 1))), strength);
        //DDLogVerbose(@"curve %f -> %f (%zu %zu)",
          //float(b) / float(size - 1) * 255.0, ch[2] * 255.0,
          //sizeof(float), sizeof(float));
        for (size_t g = 0; g < size; ++g) {
            ch[1] = lerp(float(g) / float(size - 1),
              spRGB(spG(float(g) / float(size - 1))), strength);
            for (size_t r = 0; r < size; ++r) {
                ch[0] = lerp(float(r) / float(size - 1),
                  spRGB(spR(float(r) / float(size - 1))), strength);
                for (size_t c = 0; c < 4; ++c)
                    p[c] = clamp(ch[c]);
                p += 4;
            }
        }
    }

    NSData* data = [NSData dataWithBytesNoCopy:cubeData length:cubeDataSize
      freeWhenDone:YES];
    NSAssert(data, @"TRCurves newCubeDataForSize data is nil");
    return data;
}

+ (TRCurves*) newWithInput:(CIImage*)inputImage rgb:(const Spline&)rgb
  r:(const Spline&)r g:(const Spline&)g b:(const Spline&)b
{
    DDLogVerbose(@"curves rgb:%p r:%p g:%p b:%p", &rgb, &r, &g, &b);
    TRCurves* c = [[TRCurves alloc] init];
    NSAssert(c, @"TRCurves newWithInput result is nil");
    c.inputImage = inputImage;
    c->inputRGBSpline = rgb;
    c->inputRSpline = r;
    c->inputGSpline = g;
    c->inputBSpline = b;
    c.inputStrength = [NSNumber numberWithFloat:1.0];

    [c setColorCubeSize:8];

    return c;
}

+ (TRCurves*) newWithInput:(CIImage*)inputImage rgb:(const Spline&)rgb {
    DDLogVerbose(@"curves rgb:%p", &rgb);
    Spline ident = Spline::ident();
    return [TRCurves newWithInput:inputImage rgb:rgb r:ident g:ident b:ident];
}

- (void) setColorCubeSize:(int)cubeSize {
    /*
    // If the curve has 5 knots or fewer, use CIToneCurve.
    // XXX: Actually, this doesn't work, and is slower than 3D CLUT.  (It
    // doesn't work because CIToneCurve is applied in gamma 2.0 color space.)
    const Spline iota = Spline::ident();
    if (inputRSpline == iota && inputGSpline == iota && inputBSpline == iota &&
      inputRGBSpline.knots().size() == 5) {
        DDLogWarn(@"curves will use CIToneCurve");
        return;
    }
    */

    colorCubeSize = cubeSize;

    colorCube = [TRCurves newCubeDataForSize:colorCubeSize strength:inputStrength.floatValue
      spRGB:inputRGBSpline spR:inputRSpline spG:inputGSpline spB:inputBSpline];
}

-(id)copyWithZone:(NSZone *)zone {
  TRCurves *another = [[TRCurves allocWithZone:zone] init];
  NSAssert(another, @"TRCurves copyWithZone another is nil");
  another->inputImage = nil;
  another->inputRGBSpline = inputRGBSpline;
  another->inputRSpline = inputRSpline;
  another->inputGSpline = inputGSpline;
  another->inputBSpline = inputBSpline;
  another->inputStrength = [inputStrength copyWithZone:zone];
  another->colorCubeSize = colorCubeSize;
  another->colorCube = [colorCube copyWithZone:zone];

  return another;
}

- (void) setStrength:(NSNumber*)s {
    DDLogVerbose(@"TRCurves setStrength %@", s);
    inputStrength = s;
    colorCube = [TRCurves newCubeDataForSize:colorCubeSize strength:inputStrength.floatValue
      spRGB:inputRGBSpline spR:inputRSpline spG:inputGSpline spB:inputBSpline];
}

- (CIImage*) outputImage {
    DDLogVerbose(@"TRCurves outputImage");

    NSAssert(inputImage, @"TRCurves inputImage is nil");
    
    const float strength = [inputStrength floatValue];
    if (strength < 0.01) {
        DDLogVerbose(@"TRCurves strength %f is a no-op", strength);
        return inputImage;
    }

    NSAssert(self->colorCube, @"TRCurves colorCube is nil");
    NSAssert([self->colorCube isKindOfClass:[NSData class]], @"TRCurves colorCube is not NSData!");

    CIFilter* cube = [CIFilter filterWithName:@"CIColorCube"];
    NSAssert(cube, @"TRCube outputImage cube is nil");
    [cube setDefaults];
    [cube setValue:inputImage forKey:@"inputImage"];
    [cube setValue:self->colorCube forKey:@"inputCubeData"];
    [cube setValue:[NSNumber numberWithLong:self->colorCubeSize] forKey:@"inputCubeDimension"];
    CIImage* result = cube.outputImage;
    NSAssert(result, @"TRCube outputImage result is nil");
    return result;
}

- (void)setNilValueForKey:(NSString*)key {
    //DDLogVerbose(@"TRCurves setNilValueForKey %@", key);
    if ([key isEqualToString:@"inputRGBSpline"]) {
        //inputRGBSpline = Spline::ident();
    } else if ([key isEqualToString:@"inputRSpline"]) {
        //inputRSpline = Spline::ident();
    } else if ([key isEqualToString:@"inputGSpline"]) {
        //inputGSpline = Spline::ident();
    } else if ([key isEqualToString:@"inputBSpline"]) {
        //inputBSpline = Spline::ident();
    } else {
        [super setNilValueForKey:key];
    }
}
@end
