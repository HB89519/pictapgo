#import "TRFilter.h"

static int ddLogLevel = LOG_LEVEL_INFO;

@implementation TRBlend
@synthesize inputImage;
@synthesize inputBackgroundImage;
@synthesize inputMask;
@synthesize inputMode;
@synthesize inputStrength;

NSString* filterForMode(BlendMode m) {
    switch (m) {
    case COLOR:         return @"CIColorBlendMode";
    case COLOR_BURN:    return @"CIColorBurnBlendMode";
    case COLOR_DODGE:   return @"CIColorDodgeBlendMode";
    case DARKEN:        return @"CIDarkenBlendMode";
    case DIFFERENCE:    return @"CIDifferenceBlendMode";
    case EXCLUSION:     return @"CIExclusionBlendMode";
    case HARD_LIGHT:    return @"CIHardLightBlendMode";
    case HUE:           return @"CIHueBlendMode";
    case LIGHTEN:       return @"CILightenBlendMode";
    case LINEAR_BURN:   return @"TRLinearBurn";
    case LUMINOSITY:    return @"CILuminosityBlendMode";
    case MULTIPLY:      return @"CIMultiplyBlendMode";
    case NORMAL:        return @"CISourceInCompositing";
    case OVERLAY:       return @"CIOverlayBlendMode";
    case SATURATION:    return @"CISaturationBlendMode";
    case SCREEN:        return @"CIScreenBlendMode";
    case SOFT_LIGHT:    return @"CISoftLightBlendMode";
    default: return nil;
    }
}

float softlightVal(float b, float s) {
    const float sPart = 2.0 * s - 1.0;
    float bPart;
    if (s <= 0.5)
        bPart = b - b * b;
    else
        bPart = sqrt(b) - b;
    return sPart * bPart + b;
}

NSData* blendCube(size_t dimension) {
    const size_t size = dimension;
    const size_t cubeDataSize = size * size * size * sizeof(float) * 4;
    float* cubeData = (float*)malloc(cubeDataSize);

    float* p = cubeData;
    for (size_t z = 0; z < size; ++z) {
        for (size_t y = 0; y < size; ++y) {
            for (size_t x = 0; x < size; ++x) {
                float b = float(x) / float(size - 1);
                float s = float(y) / float(size - 1);
                float v = softlightVal(b, s);
                p[0] = v, p[1] = v, p[2] = v, p[3] = 1.0;
                p += 4;
            }
        }
    }
    NSData* data = [NSData dataWithBytesNoCopy:cubeData length:cubeDataSize
      freeWhenDone:YES];
    NSCAssert(data, @"blendCube data is nil");
    return data;
}

CIFilter* channelBlend(NSData* fn, size_t dimension,
  CIImage* background, CIImage* foreground,
  CIVector* vec)
{
    CIVector* nullvec = [CIVector vectorWithX:0.0 Y:0.0 Z:0.0 W:0.0];

    CIFilter* bg = [CIFilter filterWithName:@"CIColorMatrix"];
    NSCAssert(bg, @"channelBlend bg is nil");
    [bg setDefaults];
    [bg setValue:background forKey:@"inputImage"];
    [bg setValue:vec forKey:@"inputRVector"];
    [bg setValue:nullvec forKey:@"inputGVector"];
    [bg setValue:nullvec forKey:@"inputBVector"];

    CIFilter* fg = [CIFilter filterWithName:@"CIColorMatrix"];
    NSCAssert(fg, @"channelBlend fg is nil");
    [fg setDefaults];
    [fg setValue:foreground forKey:@"inputImage"];
    [fg setValue:nullvec forKey:@"inputRVector"];
    [fg setValue:vec forKey:@"inputGVector"];
    [fg setValue:nullvec forKey:@"inputBVector"];

    CIFilter* comp = [CIFilter filterWithName:@"CIMaximumCompositing"];
    NSCAssert(comp, @"channelBlend comp is nil");
    [comp setDefaults];
    [comp setValue:bg.outputImage forKey:@"inputBackgroundImage"];
    [comp setValue:fg.outputImage forKey:@"inputImage"];

    CIFilter* cube = [CIFilter filterWithName:@"CIColorCube"];
    NSCAssert(cube, @"channelBlend cube is nil");
    [cube setDefaults];
    [cube setValue:comp.outputImage forKey:@"inputImage"];
    [cube setValue:fn forKey:@"inputCubeData"];
    [cube setValue:[NSNumber numberWithLong:dimension]
      forKey:@"inputCubeDimension"];

    return cube;
}

CIFilter* combine(CIImage* r, CIImage* g, CIImage* b) {
    CIFilter* ch_r = [CIFilter filterWithName:@"CIColorMatrix"];
    NSCAssert(ch_r, @"combine ch_r is nil");
    [ch_r setDefaults];
    [ch_r setValue:r forKey:@"inputImage"];
    [ch_r setValue:[CIVector vectorWithX:1.0 Y:0.0 Z:0.0 W:0.0]
      forKey:@"inputRVector"];
    [ch_r setValue:[CIVector vectorWithX:0.0 Y:0.0 Z:0.0 W:0.0]
      forKey:@"inputGVector"];
    [ch_r setValue:[CIVector vectorWithX:0.0 Y:0.0 Z:0.0 W:0.0]
      forKey:@"inputBVector"];

    CIFilter* ch_g = [CIFilter filterWithName:@"CIColorMatrix"];
    NSCAssert(ch_g, @"combine ch_g is nil");
    [ch_g setDefaults];
    [ch_g setValue:g forKey:@"inputImage"];
    [ch_g setValue:[CIVector vectorWithX:0.0 Y:0.0 Z:0.0 W:0.0]
      forKey:@"inputRVector"];
    [ch_g setValue:[CIVector vectorWithX:0.0 Y:1.0 Z:0.0 W:0.0]
      forKey:@"inputGVector"];
    [ch_g setValue:[CIVector vectorWithX:0.0 Y:0.0 Z:0.0 W:0.0]
      forKey:@"inputBVector"];

    CIFilter* ch_b = [CIFilter filterWithName:@"CIColorMatrix"];
    NSCAssert(ch_b, @"combine cg_b is nil");
    [ch_b setDefaults];
    [ch_b setValue:b forKey:@"inputImage"];
    [ch_b setValue:[CIVector vectorWithX:0.0 Y:0.0 Z:0.0 W:0.0]
      forKey:@"inputRVector"];
    [ch_b setValue:[CIVector vectorWithX:0.0 Y:0.0 Z:0.0 W:0.0]
      forKey:@"inputGVector"];
    [ch_b setValue:[CIVector vectorWithX:0.0 Y:0.0 Z:1.0 W:0.0]
      forKey:@"inputBVector"];

    CIFilter* ch_rg = [CIFilter filterWithName:@"CIMaximumCompositing"];
    NSCAssert(ch_rg, @"combine cg_rg is nil");
    [ch_rg setDefaults];
    [ch_rg setValue:ch_r.outputImage forKey:@"inputBackgroundImage"];
    [ch_rg setValue:ch_g.outputImage forKey:@"inputImage"];

    CIFilter* ch_rgb = [CIFilter filterWithName:@"CIMaximumCompositing"];
    NSCAssert(ch_rgb, @"combine cg_rgb is nil");
    [ch_rgb setDefaults];
    [ch_rgb setValue:ch_rg.outputImage forKey:@"inputBackgroundImage"];
    [ch_rgb setValue:ch_b.outputImage forKey:@"inputImage"];

    return ch_rgb;
}


CIFilter* trSoftLight(CIImage* background, CIImage* foreground) {
    DDLogCVerbose(@"trSoftLight setup");
    size_t size = 16;
    NSData* data = blendCube(size);

    CIFilter* ch_r = channelBlend(data, size, background, foreground,
      [CIVector vectorWithX:1.0 Y:0.0 Z:0.0 W:0.0]);
    CIFilter* ch_g = channelBlend(data, size, background, foreground,
      [CIVector vectorWithX:0.0 Y:1.0 Z:0.0 W:0.0]);
    CIFilter* ch_b = channelBlend(data, size, background, foreground,
      [CIVector vectorWithX:0.0 Y:0.0 Z:1.0 W:0.0]);

    CIFilter* result = combine(ch_r.outputImage, ch_g.outputImage, ch_b.outputImage);
    DDLogCVerbose(@"trSoftLight setup done");
    return result;
}

CIFilter* trLinearBurn(CIImage* background, CIImage* foreground) {
    CIFilter* bg = [CIFilter filterWithName:@"CIColorMatrix"];
    NSCAssert(bg, @"trLinearBurn bg is nil");
    CIFilter* fg = [CIFilter filterWithName:@"CIColorMatrix"];
    NSCAssert(fg, @"trLinearBurn fg is nil");

    [bg setDefaults];
    [bg setValue:background forKey:@"inputImage"];
    [bg setValue:[CIVector vectorWithX:0.5 Y:0 Z:0] forKey:@"inputRVector"];
    [bg setValue:[CIVector vectorWithX:0 Y:0.5 Z:0] forKey:@"inputGVector"];
    [bg setValue:[CIVector vectorWithX:0 Y:0 Z:0.5] forKey:@"inputBVector"];

    [fg setDefaults];
    [fg setValue:foreground forKey:@"inputImage"];
    [fg setValue:[CIVector vectorWithX:0.5 Y:0 Z:0] forKey:@"inputRVector"];
    [fg setValue:[CIVector vectorWithX:0 Y:0.5 Z:0] forKey:@"inputGVector"];
    [fg setValue:[CIVector vectorWithX:0 Y:0 Z:0.5] forKey:@"inputBVector"];

    CIFilter* blend = [CIFilter filterWithName:@"CIAdditionCompositing"];
    [blend setDefaults];
    [blend setValue:bg.outputImage forKey:@"inputBackgroundImage"];
    [blend setValue:fg.outputImage forKey:@"inputImage"];

    // XXX: I don't understand why the bias vector is -0.5 not -1.0.
    // However, using -1.0 results in a completely black image.  It's as if
    // the bias vector is being added PRIOR TO the other multiplication.
    CIFilter* result = [CIFilter filterWithName:@"CIColorMatrix"];
    [result setDefaults];
    [result setValue:blend.outputImage forKey:@"inputImage"];
    [result setValue:[CIVector vectorWithX:2.0 Y:0 Z:0] forKey:@"inputRVector"];
    [result setValue:[CIVector vectorWithX:0 Y:2.0 Z:0] forKey:@"inputGVector"];
    [result setValue:[CIVector vectorWithX:0 Y:0 Z:2.0] forKey:@"inputBVector"];
    [result setValue:[CIVector vectorWithX:-0.5 Y:-0.5 Z:-0.5] forKey:@"inputBiasVector"];

    NSCAssert(result, @"trLinearBurn result is nil");
    return result;
}

- (CIImage*) outputImage {
    float strength = [inputStrength floatValue];

    if (strength < 0.01) {
        DDLogVerbose(@"TRBlend strength %f is a no-op", strength);
        return inputBackgroundImage;
    }

    BlendMode mode = (BlendMode)[inputMode intValue];
    if (strength >= 0.99 && mode == NORMAL && !inputMask) {
        DDLogVerbose(@"TRBlend NORMAL strength %f returning input image", strength);
        return inputImage;
    }
    
    DDLogVerbose(@"TRBlend strength %f mode %@", strength, filterForMode(mode));
    
    if (mode == SOFT_LIGHT) {
        //blend = trSoftLight(inputBackgroundImage, inputImage);
        mode = HARD_LIGHT;
        strength /= 2.0;
    }

    NSAssert(strength <= 1.0 && strength >= 0,
      @"strength not between 0.0 - 1.0: %f", strength);

    CIFilter* blend;
    if (mode == LINEAR_BURN) {
        blend = trLinearBurn(inputBackgroundImage, inputImage);
    } else {
        NSString* modeFilterName = filterForMode(mode);
        blend = [CIFilter filterWithName:modeFilterName];
        [blend setDefaults];
        [blend setValue:inputBackgroundImage forKey:@"inputBackgroundImage"];
        [blend setValue:inputImage forKey:@"inputImage"];
        NSAssert(blend, @"TRBlend outputImage blend is nil");
    }

    if (strength >= 0.99 && !inputMask) {
        DDLogVerbose(@"TRBlend %@ strength %f, no masking needed",
          filterForMode(mode), strength);
        return blend.outputImage;
    }

    CIImage* result;

    if (inputMask) {
        CIFilter* maskBlend = [CIFilter filterWithName:@"CIBlendWithMask"];
        NSAssert(maskBlend, @"TRBlend outputImage maskBlend is nil");
        [maskBlend setDefaults];
        [maskBlend setValue:inputImage forKey:@"inputImage"];
        [maskBlend setValue:inputBackgroundImage forKey:@"inputBackgroundImage"];
        [maskBlend setValue:inputMask forKey:@"inputMaskImage"];

        result = maskBlend.outputImage;
    } else {
        CIFilter* alpha = [CIFilter filterWithName:@"CIColorMatrix"];
        NSAssert(alpha, @"TRBlend outputImage alpha is nil");
        [alpha setDefaults];
        [alpha setValue:blend.outputImage forKey:@"inputImage"];
        [alpha setValue:[CIVector vectorWithX:0 Y:0 Z:0 W:strength] forKey:@"inputAVector"];

        CIFilter* fblend = [CIFilter filterWithName:@"CISourceAtopCompositing"];
        NSAssert(fblend, @"TRBlend outputImage fblend is nil");
        [fblend setDefaults];
        [fblend setValue:alpha.outputImage forKey:@"inputImage"];
        [fblend setValue:inputBackgroundImage forKey:@"inputBackgroundImage"];

        result = fblend.outputImage;
    }
    
    NSAssert(result, @"TRBlend outputImage result is nil");
    return result;
}

+ (TRBlend*) newWithInput:(CIImage*)fg background:(CIImage*)bg {
    TRBlend* b = [[TRBlend alloc] init];
    b.inputImage = fg;
    b.inputBackgroundImage = bg;
    b.inputMode = [NSNumber numberWithInt:NORMAL];
    b.inputStrength = [NSNumber numberWithFloat:1.0];
    return b;
}

+ (TRBlend*) newWithInput:(CIImage*)fg background:(CIImage*)bg
  mode:(BlendMode)mode
{
    TRBlend* b = [[TRBlend alloc] init];
    b.inputImage = fg;
    b.inputBackgroundImage = bg;
    b.inputMode = [NSNumber numberWithInt:mode];
    b.inputStrength = [NSNumber numberWithFloat:1.0];
    return b;
}

+ (TRBlend*) newWithInput:(CIImage*)fg background:(CIImage*)bg
  mode:(BlendMode)mode strength:(NSNumber*)strength
{
    TRBlend* b = [[TRBlend alloc] init];
    b.inputImage = fg;
    b.inputBackgroundImage = bg;
    b.inputMode = [NSNumber numberWithInt:mode];
    b.inputStrength = strength;
    return b;
}

+ (TRBlend*) newWithInput:(CIImage*)fg background:(CIImage*)bg
  mask:(CIImage*)mask
{
    TRBlend* b = [[TRBlend alloc] init];
    b.inputImage = fg;
    b.inputBackgroundImage = bg;
    b.inputMode = [NSNumber numberWithInt:NORMAL];
    b.inputStrength = [NSNumber numberWithFloat:1.0];
    b.inputMask = mask;
    return b;
}

@end
