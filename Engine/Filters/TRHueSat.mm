#include <ostream>
#import "TRFilter.h"
#import "HSLColor.h"

static int ddLogLevel = LOG_LEVEL_INFO;

float iroundf(float v) {
    if (v > 0.0) return int(std::floor(v + 0.5));
    if (v < 0.0) return int(std::ceil(v - 0.5));
    return 0;
}

std::ostream& operator<<(std::ostream& s, const HSLColor& c) {
    return s << "HSL(" << iroundf(c.h*360) << "," << iroundf(c.s*100) << ","
      << iroundf(c.l*100) << ")";
}

std::ostream& operator<<(std::ostream& s, const CGColorRef& c) {
    const CGFloat* ch = CGColorGetComponents(c);
    return s << "RGB(" << iroundf(ch[0]*255) << "," << iroundf(ch[1]*255)
      << "," << iroundf(ch[2]*255) << ")";
}

std::ostream& operator<<(std::ostream& s, const HueSatAdjustments::Slice& l) {
    return s << "(" << l.range[0] << "," << l.range[1] << ","
      << l.range[2] << "," << l.range[3] << ")["
      << l.hue << "," << l.saturation << "," << l.lightness << "]";
}

@implementation TRHueSat;
@synthesize inputImage;
@synthesize inputHueSat;
@synthesize inputStrength;

struct HueSatFunctor {
    struct HSLDelta {
        HSLDelta() : hue(0), saturation(0), lightness(0), masterLightness(0) {}
        float hue;          // range -1.0,1.0
        float saturation;   // range -1.0,1.0
        float lightness;    // range -1.0,1.0
        float masterLightness;
        void addHue(float h) { hue += h / 360.0f; }
        void addSaturation(float s) { saturation += s; }
        void addLightness(float l) { lightness += l; }
        void addMasterLightness(float l) { masterLightness += l; }
        void finalize() {
            if (saturation > 1.0f) saturation = 1.0f;
            else if (saturation < -1.0f) saturation = -1.0f;
        }
    };

    HueSatFunctor(const HueSatAdjustments& adj) {
        for (size_t i = 0; i < adj.slices.size(); ++i)
            addSlice(adj.slices[i]);
        finalize();
    }

    const HSLDelta& deltasFor(float hue) const {
        const int currentHueIndex = norm360(iroundf(hue * 360.f));
        NSCAssert(currentHueIndex >= 0 && currentHueIndex < 360,
          @"currentHueIndex=%d", currentHueIndex);
        return deltas[currentHueIndex];
    }
    
    CGColorRef operator()(HSLColor c, CGColorSpaceRef colorSpace) const {
        const HSLDelta& d = deltasFor(c.h);

        c.h += d.hue;

        if (d.saturation > 0) {
            // note that clipping to 1.01 would give us a divide
            // by zero error
            c.s += c.s * ((-1.0f / (d.saturation - 1.01f)) - 1.01f);
        } else {
            c.s += c.s * d.saturation;
        }


        c.l = clamp(c.l);
        c.s = clamp(c.s);

        while (c.h > 1.0f) { c.h = c.h - 1.0f; }
        while (c.h < 0.0f) { c.h = c.h + 1.0f; }

        CGColorRef cgColor = CGColorCreateWithHSLColor(c);
        const CGFloat* cgPxl = CGColorGetComponents(cgColor);
        CGFloat pxl[4];
        pxl[0] = cgPxl[0];
        pxl[1] = cgPxl[1];
        pxl[2] = cgPxl[2];
        pxl[3] = 1.0;
        CGColorRelease(cgColor);

        // lightness is fairly strange, so I'm going to go over it in
        // depth. First, this lightness isn't equivalent to the HSL
        // model, instead it's a smooth lighting based on the RGB
        // values of each pixel. The lower bound for values when
        // using a negative lightness is the smallest RGB value
        //(though this doesn't mean all values will necessarily
        // hit that lower bound at -1 lightness), and similar upper
        // bound.
        if (d.lightness != 0 ) {
            CGFloat *hV, *mV, *lV;

            // sort out the highest to lowest RGB values
            if (pxl[0] >= pxl[1] && pxl[0] >= pxl[2]) {
                hV = &(pxl[0]);
                if (pxl[1] >= pxl[2]) {
                    mV = &(pxl[1]); lV = &(pxl[2]);
                } else {
                    mV = &(pxl[2]); lV = &(pxl[1]);
                }
            } else if (pxl[1] >= pxl[0] && pxl[1] >= pxl[2]) {
                hV = &(pxl[1]);
                if (pxl[0] >= pxl[2]) {
                    mV = &(pxl[0]); lV = &(pxl[2]);
                } else {
                    mV = &(pxl[2]); lV = &(pxl[0]);
                }
            } else {
                hV = &(pxl[2]);
                if (pxl[0] >= pxl[1]) {
                    mV = &(pxl[0]); lV = &(pxl[1]);
                } else {
                    mV = &(pxl[1]); lV = &(pxl[0]);
                }
            }

            CGFloat hTmp = *hV;
            CGFloat mTmp = *mV;
            CGFloat lTmp = *lV;

            // here's where things start getting strange. We need the
            // midpoint between the high and low values, as well as the
            // distances between all three. The actual lower and upper
            // bounds are offset by midFromMidval, which is the amount
            // of overlap between the midpoint and the middle value
            // pushed toward the center a distance equal to the distance
            // from its closest neighbor. It is 0 if the calculation
            // yields a negative value.
            CGFloat lhMidpoint = (hTmp + lTmp) / 2;
            CGFloat lhDist = (hTmp - lTmp);
            CGFloat lmDist = (mTmp - lTmp);
            CGFloat mhDist = (hTmp - mTmp);

            CGFloat midFromMidval;
            if (lmDist < mhDist) {
                midFromMidval = (mTmp + lmDist) - lhMidpoint;
            } else {
                midFromMidval = lhMidpoint - (mTmp - mhDist);
            }

            if (midFromMidval < 0) {
                midFromMidval = 0;
            }

            if (lhDist == 0) {
                //do nothing
            } else if (d.lightness < 0 ) {
                hTmp = clamp(hTmp - d.lightness *
                  ((lTmp + midFromMidval) - hTmp));
                mTmp = clamp(mTmp - d.lightness *
                  ((lTmp + midFromMidval * float(lmDist / lhDist)) - mTmp));
            } else {
                mTmp = clamp(mTmp + d.lightness *
                  ((hTmp - midFromMidval * float(mhDist / lhDist)) - mTmp));
                lTmp = clamp(lTmp + d.lightness *
                  ((hTmp - midFromMidval) - lTmp));
            }

            *hV = hTmp;
            *mV = mTmp;
            *lV = lTmp;
        }

        // this is the lightness for the master HueSat adjustment,
        // which is a different algorithm than the other lightness
        float lRatio = (d.masterLightness / 100.0f);

        if (lRatio > 0.0f) {
            pxl[0] = clamp(pxl[0] + (1.0f - pxl[0]) * lRatio);
            pxl[1] = clamp(pxl[1] + (1.0f - pxl[1]) * lRatio);
            pxl[2] = clamp(pxl[2] + (1.0f - pxl[2]) * lRatio);
        } else if (lRatio < 0.0f) {
            pxl[0] = clamp(pxl[0] + (pxl[0]) * lRatio);
            pxl[1] = clamp(pxl[1] + (pxl[1]) * lRatio);
            pxl[2] = clamp(pxl[2] + (pxl[2]) * lRatio);
        }

        CGColorRef result = CGColorCreate(colorSpace, pxl);
        return result;
    }
private:
    HSLDelta deltas[360];
    friend std::ostream& operator<<(std::ostream& s, const HSLDelta& d) {
        return s << 360.0 * d.hue << "," << d.saturation << ","
          << d.lightness << "," << d.masterLightness;
    }

    static float clamp(float v) { return std::max(0.0f, std::min(1.0f, v)); }

    static int norm360(int a) { return (a + 360) % 360; }

    void addSlice(const HueSatAdjustments::Slice& slice) {
        int loFthr  = slice.range[0];
        int loSlce  = slice.range[1];
        int hiSlce  = slice.range[2];
        int hiFthr  = slice.range[3];
        int hue     = slice.hue;
        float saturation = slice.saturation;
        float lightness  = slice.lightness;

        if (loSlce < loFthr) loSlce += 360;
        if (hiSlce < loSlce) hiSlce += 360;
        if (hiFthr < hiSlce) hiFthr += 360;

        if (loFthr == hiFthr) {
            for (uint16_t i = 0; i < 360; ++i) {
                deltas[i].addHue(float(hue));
                deltas[i].addSaturation(saturation);
                deltas[i].addMasterLightness(lightness);
            }
        } else {
            for (int i = loFthr; i < hiFthr; ++i) {
                float amount = 0.0f;
                if (i < loSlce) {
                    amount = float(i - loFthr) / float(loSlce - loFthr);
                } else if (i < hiSlce) {
                    amount = 1.0f;
                } else if (i < hiFthr) {
                    amount = 1.0f - float(i - hiSlce) / float(hiFthr - hiSlce);
                }
                HSLDelta& b = deltas[norm360(i)];
                b.addHue(amount * hue);
                b.addSaturation(amount * saturation);
                b.addLightness(amount * (2.0f - amount) * lightness);
            }
        }
    }

    void finalize() {
        for (int i = 0; i < 360; ++i)
            deltas[i].finalize();
    }
};

NSData* hslCube(size_t dimension, const HueSatAdjustments& adj) {
    const size_t size = dimension;
    const size_t cubeDataSize = size * size * size * sizeof(float) * 4;
    float* cubeData = (float*)malloc(cubeDataSize);

    HueSatFunctor fn(adj);

    CGColorSpaceRef dRGB = CGColorSpaceCreateDeviceRGB();
    float* p = cubeData;
    for (size_t b = 0; b < size; ++b) {
        for (size_t g = 0; g < size; ++g) {
            for (size_t r = 0; r < size; ++r) {
                const CGFloat ch[4] = { float(r) / float(size - 1),
                  float(g) / float(size - 1), float(b) / float(size - 1), 1.0};
                CGColorRef rgb = CGColorCreate(dRGB, ch);
                NSCAssert(rgb, @"TRHueSat hslCube rgb is nil");

                const HSLColor hsl(rgb);
                CGColorRef newColor = fn(hsl, dRGB);
                const CGFloat* c = CGColorGetComponents(newColor);
                NSCAssert(c, @"TRHueSat hslCube c is nil");
                p[0] = c[0], p[1] = c[1], p[2] = c[2], p[3] = c[3];

                CGColorRelease(rgb);
                CGColorRelease(newColor);
                p += 4;
            }
        }
    }
    CGColorSpaceRelease(dRGB);
    
    NSData* data = [NSData dataWithBytesNoCopy:cubeData length:cubeDataSize
      freeWhenDone:YES];
    NSCAssert(data, @"TRHueSat hslCube data is nil");
    return data;
}

+ (TRHueSat*) newWithInput:(CIImage*)inputImage
  hueSat:(const HueSatAdjustments&)hueSat strength:(NSNumber*)inputStrength
{
    TRHueSat* result = [[TRHueSat alloc] init];
    NSAssert(result, @"TRHueSat newWithInput result is nil");
    result.inputImage = inputImage;
    result.inputHueSat = hueSat;
    result.inputStrength = inputStrength;

    result->colorCubeSize = 16;
    result->colorCube = hslCube(result->colorCubeSize, result.inputHueSat);

    return result;
}

+ (TRHueSat*) newWithInput:(CIImage*)inputImage
  hueSat:(const HueSatAdjustments&)hueSat
{
    return [TRHueSat newWithInput:inputImage hueSat:hueSat
      strength:[NSNumber numberWithFloat:1]];
}

-(id)copyWithZone:(NSZone *)zone {
  TRHueSat *another = [[TRHueSat allocWithZone:zone] init];
  NSAssert(another, @"TRHueSat copyWithZone another is nil");
  another->inputImage = nil;
  another->inputHueSat = inputHueSat;
  another->inputStrength = [inputStrength copyWithZone:zone];
  another->colorCubeSize = colorCubeSize;
  another->colorCube = [colorCube copyWithZone:zone];

  return another;
}

- (CIImage*) outputImage {
    DDLogVerbose(@"TRHueSat outputImage");

    NSAssert(self->colorCube, @"TRHueSat colorCube is nil");
    NSAssert([self->colorCube isKindOfClass:[NSData class]], @"TRHueSat colorCube is not NSData!");

    CIFilter* cube = [CIFilter filterWithName:@"CIColorCube"];
    NSAssert(cube, @"TRHueSat outputImage cube is nil");
    [cube setDefaults];
    [cube setValue:inputImage forKey:@"inputImage"];
    [cube setValue:self->colorCube forKey:@"inputCubeData"];
    [cube setValue:[NSNumber numberWithLong:self->colorCubeSize]
      forKey:@"inputCubeDimension"];

    CIImage* result = cube.outputImage;
    NSAssert(result, @"TRHueSat outputImage result is nil for cube %@", cube);
    return result;
}

- (void)setNilValueForKey:(NSString*)key {
    DDLogVerbose(@"TRHueSat setNilValueForKey %@", key);
    if ([key isEqualToString:@"inputHueSat"]) {
        inputHueSat = HueSatAdjustments();
    } else {
        [super setNilValueForKey:key];
    }
}

@end
