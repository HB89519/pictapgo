#if TARGET_OS_IPHONE
# import <CoreImage/CoreImage.h>
#else
# import <Cocoa/Cocoa.h>
# import <QuartzCore/CIContext.h>
# import <QuartzCore/CIFilter.h>
#endif
#import <Accelerate/Accelerate.h>
#import "Spline.hpp"

inline float imageDiagonal(CGSize sz) {
    return sqrt(sz.width * sz.width + sz.height * sz.height);
}

inline float scaledRadius(CGSize sz, float radiusPercentage) {
    const float diagonal = imageDiagonal(sz);
    const float radius = diagonal * radiusPercentage;
    return radius;
}

@interface TRFilter : NSObject
@property CIImage* inputImage;
@property (readonly) CIImage* outputImage;
@end

@interface TRAccelerateFrameworkFilter : TRFilter
@property (readonly) CIImage* outputImage;
- (vImage_Error) runVImageOperation:(vImage_Buffer*)input
  output:(vImage_Buffer*)output;
@end

@interface TRBlur: TRFilter {
    NSNumber* inputRadius;
}
+ (TRBlur*) newWithInput:(CIImage*)inputImage radius:(NSNumber*)blurRadius;
@property (retain, nonatomic) NSNumber* inputRadius;
@end

@interface TRUnsharpMask: TRFilter {
    NSNumber* inputRadius;
    NSNumber* inputAmount;
}
+ (TRUnsharpMask*) newWithInput:(CIImage*)inputImage radius:(NSNumber*)radius
  amount:(NSNumber*)amount;
@property (retain, nonatomic) NSNumber* inputRadius;
@property (retain, nonatomic) NSNumber* inputAmount;
@end

struct LevelsAdjustments;

struct ColorMap {
    uint8_t t[3][256][4];
    ColorMap() {
        for (int i = 0; i < 256; ++i) {
            t[0][i][0] = 255; t[0][i][1] = i; t[0][i][2] = 0; t[0][i][3] = 0;
            t[1][i][0] = 255; t[1][i][1] = 0; t[1][i][2] = i; t[1][i][3] = 0;
            t[2][i][0] = 255; t[2][i][1] = 0; t[2][i][2] = 0; t[2][i][3] = i;
        }
    }

    typedef tr::util::Spline Spline;
    ColorMap(const Spline& c,
      const Spline& r, const Spline& g, const Spline& b, float strength);

    ColorMap(const LevelsAdjustments&, float strength);
};

@interface TRColorMap: TRFilter {
    ColorMap inputMap;
}
+ (TRColorMap*) newWithInput:(CIImage*)inputImage map:(ColorMap)inputMap;
@property (nonatomic) ColorMap inputMap;
@end

@interface TRCurves: TRFilter <NSCopying> {
    tr::util::Spline inputRGBSpline;
    tr::util::Spline inputRSpline;
    tr::util::Spline inputGSpline;
    tr::util::Spline inputBSpline;
    NSNumber* inputStrength;
    size_t colorCubeSize;
    NSData* colorCube;
}

+ (TRCurves*) newWithInput:(CIImage*)inputImage rgb:(const tr::util::Spline&)rgb;
+ (TRCurves*) newWithInput:(CIImage*)inputImage rgb:(const tr::util::Spline&)rgb
  r:(const tr::util::Spline&)r g:(const tr::util::Spline&)g
  b:(const tr::util::Spline&)b;

- (void) setStrength:(NSNumber*)strength;
- (void) setColorCubeSize:(int)cubeSize;

@property (retain, nonatomic) NSNumber* inputStrength;
@end

enum BlendMode {
    COLOR,
    COLOR_BURN,
    COLOR_DODGE,
    DARKEN,
    DIFFERENCE,
    EXCLUSION,
    HARD_LIGHT,
    HUE,
    LIGHTEN,
    LINEAR_BURN,
    LUMINOSITY,
    MULTIPLY,
    NORMAL,
    OVERLAY,
    SATURATION,
    SCREEN,
    SOFT_LIGHT
};

@interface TRBlend: TRFilter {
    CIImage* inputBackgroundImage;
    CIImage* inputMask;
    NSNumber* inputMode;
    NSNumber* inputStrength;
}

+ (TRBlend*) newWithInput:(CIImage*)fg background:(CIImage*)bg;
+ (TRBlend*) newWithInput:(CIImage*)fg background:(CIImage*)bg
  mode:(BlendMode)mode;
+ (TRBlend*) newWithInput:(CIImage*)fg background:(CIImage*)bg
  mode:(BlendMode)mode strength:(NSNumber*)strength;
+ (TRBlend*) newWithInput:(CIImage*)fg background:(CIImage*)bg
  mask:(CIImage*)mask;

@property (retain, nonatomic) CIImage* inputBackgroundImage;
@property (retain, nonatomic) CIImage* inputMask;
@property (retain, nonatomic) NSNumber* inputMode;
@property (retain, nonatomic) NSNumber* inputStrength;
@end

typedef enum { kAddGrainGaussian, kAddGrainUniform } AddGrainNoiseMode;

@interface TRAddGrain: TRFilter {
    NSNumber* graininess;
    AddGrainNoiseMode noiseMode;
    CGSize size;
}

+ (TRAddGrain*) newWithSize:(CGSize)size graininess:(NSNumber*)graininess;
@property (retain, nonatomic) NSNumber* graininess;
@property (nonatomic) CGSize size;
@property (nonatomic) AddGrainNoiseMode noiseMode;
@end

@interface TRGradient: TRFilter {
    NSNumber* inputRadius;
    CGSize masterSize;
}

+ (TRGradient*) newWithInput:(CIImage*)inputImage radius:(NSNumber*)radius
  masterSize:(CGSize)masterSize;

@property (retain, nonatomic) NSNumber* inputRadius;
@property (nonatomic) CGSize masterSize;
@end

@interface TRSolidColor: TRFilter {
    CIColor* inputColor;
    CGSize inputSize;
}

+ (TRSolidColor*) newWithR:(float)red G:(float)green B:(float)blue
  size:(CGSize)size;

@property (retain, nonatomic) CIColor* inputColor;
@property (nonatomic) CGSize inputSize;
@end

@interface TRLabGrey: TRFilter
+ (TRLabGrey*) newWithInput:(CIImage*)inputImage;
@end

@interface TRRollup: TRFilter
+ (TRRollup*) newWithInput:(CIImage*)inputImage;
@end

@interface TRGreyMix: TRFilter {
    CIVector* inputVector;
}

+ (TRGreyMix*) newWithInput:(CIImage*)inputImage;
+ (TRGreyMix*) newWithInput:(CIImage*)inputImage
  r:(NSNumber*)r g:(NSNumber*)g b:(NSNumber*)b;
+ (TRGreyMix*) newWithInput:(CIImage*)inputImage mix:(CIVector*)mix;

@property (retain, nonatomic) CIVector* inputVector;
@end

@interface TRChannelMix: TRFilter {
    CIVector* inputRVector;
    CIVector* inputGVector;
    CIVector* inputBVector;
    CIVector* inputBiasVector;
}

+ (TRChannelMix*) newWithInput:(CIImage*)inputImage
  r:(CIVector*)r g:(CIVector*)g b:(CIVector*)b;

+ (TRChannelMix*) newWithInput:(CIImage*)inputImage
  r:(CIVector*)r g:(CIVector*)g b:(CIVector*)b bias:(CIVector*)bias;;

@property (retain, nonatomic) CIVector* inputRVector;
@property (retain, nonatomic) CIVector* inputGVector;
@property (retain, nonatomic) CIVector* inputBVector;
@property (retain, nonatomic) CIVector* inputBiasVector;
@end

// TODO: make this more idiomatic for Objective C
struct HueSatAdjustments {
    struct Slice {
        Slice() : hue(0), saturation(0), lightness(0)
          { range[0] = range[1] = range[2] = range[3] = 0; }
        Slice(int fLo, int lo, int hi, int fHi, int h, float s, float l) :
          hue(h), saturation(s), lightness(l)
          { range[0] = fLo, range[1] = lo, range[2] = hi, range[3] = fHi; }
        int range[4];  // hues in range [0,360)
        int hue;  // hue adjustment, range [0,360)
        float saturation, lightness; // S and L adjustments, range [-1,1]
    };
    typedef std::vector<Slice> Slices;
    Slices slices;
};

@interface TRHueSat: TRFilter <NSCopying> {
    HueSatAdjustments inputHueSat;
    NSNumber* inputStrength;
    size_t colorCubeSize;
    NSData* colorCube;
}

+ (TRHueSat*) newWithInput:(CIImage*)inputImage
  hueSat:(const HueSatAdjustments&)hueSat;
+ (TRHueSat*) newWithInput:(CIImage*)inputImage
  hueSat:(const HueSatAdjustments&)hueSat strength:(NSNumber*)inputStrength;

@property (nonatomic) HueSatAdjustments inputHueSat;
@property (retain, nonatomic) NSNumber* inputStrength;
@end

@interface TRAutoColor: TRAccelerateFrameworkFilter
+ (TRAutoColor*) newWithInput:(CIImage*)inputImage;
@end

@interface TREqualize: TRAccelerateFrameworkFilter
+ (TREqualize*) newWithInput:(CIImage*)inputImage;
@end

//@interface TRFindEdges: TRAccelerateFrameworkFilter
//+ (TRFindEdges*) newWithInput:(CIImage*)inputImage;
//@end

@interface TRCube: TRFilter <NSCopying> {
    size_t colorCubeSize;
    NSData* colorCube;
}

+ (TRCube*) newWithInput:(CIImage*)inputImage
  cube:(CGImageRef)cube size:(NSUInteger)size;

+ (TRCube*) newWithInput:(CIImage*)inputImage
  cubeFile:(NSString*)filename size:(NSUInteger)size;

@end

// TODO: Make this idiomatic Objective C
struct LevelsAdjustments {
    struct Adjustment {
        Adjustment() :
          gamma(1.0), inMin(0), inMax(255), outMin(0), outMax(255) {}
        float gamma;
        int inMin, inMax;
        int outMin, outMax;
        friend std::ostream& operator<<(std::ostream&, const Adjustment&);
    };
    Adjustment adj[4];
    friend std::ostream& operator<<(std::ostream&, const LevelsAdjustments&);
};

@interface TRLevels: TRFilter <NSCopying> {
    LevelsAdjustments inputLevels;
    NSNumber* inputStrength;
    size_t colorCubeSize;
    NSData* colorCube;
}

+ (TRLevels*) newWithInput:(CIImage*)inputImage
  levels:(const LevelsAdjustments&)levels;
+ (TRLevels*) newWithInput:(CIImage*)inputImage
  levels:(const LevelsAdjustments&)levels strength:(NSNumber*)strength;

- (void) setStrength:(NSNumber*)strength;

@property (nonatomic) LevelsAdjustments inputLevels;
@property (retain, nonatomic) NSNumber* inputStrength;
@end

@interface TRHighPass: TRFilter {
    CIImage* inputBlurredImage;
    NSNumber* inputBrightness;
}

+ (TRHighPass*) newWithInput:(CIImage*)inputImage blurredImage:(CIImage*)blurredImage
  brightness:(NSNumber*)brightness;
+ (TRHighPass*) newWithInput:(CIImage*)inputImage blurredImage:(CIImage*)blurredImage;

@property (retain, nonatomic) CIImage* inputBlurredImage;
@property (retain, nonatomic) NSNumber* inputBrightness;
@end

