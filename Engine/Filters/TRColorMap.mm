#include <iostream>
#import "TRFilter.h"
#import "DDLog.h"

static int ddLogLevel = LOG_LEVEL_INFO;

@implementation TRColorMap
@synthesize inputImage;
@synthesize inputMap;

int iclamp(float v) { return std::max(0.0f, std::min(255.0f, roundf(v))); }

ColorMap::ColorMap(const Spline& c,
  const Spline& r, const Spline& g, const Spline& b, float strength)
{
    for (int i = 0; i < 256; ++i) {
        float ch = r(float(i) / 255.0);
        ch = c(ch) * 255.0;
        ch = float(i) + (ch - float(i)) * strength;
        int v = iclamp(ch);
        t[0][i][0] = 255; t[0][i][1] = v; t[0][i][2] = 0; t[0][i][3] = 0;
    }

    for (int i = 0; i < 256; ++i) {
        float ch = g(float(i) / 255.0);
        ch = c(ch) * 255.0;
        ch = float(i) + (ch - float(i)) * strength;
        int v = iclamp(ch);
        t[1][i][0] = 255; t[1][i][1] = 0; t[1][i][2] = v; t[1][i][3] = 0;
    }

    for (int i = 0; i < 256; ++i) {
        float ch = b(float(i) / 255.0);
        ch = c(ch) * 255.0;
        ch = float(i) + (ch - float(i)) * strength;
        int v = iclamp(ch);
        t[2][i][0] = 255; t[2][i][1] = 0; t[2][i][2] = 0; t[2][i][3] = v;
    }
}

void fillTable(uint8_t t[256], const LevelsAdjustments::Adjustment& a) {
    for (int i = 0; i < 256; ++i) {
        if (i < a.inMin)
            t[i] = a.outMin;
        if (i > a.inMax)
            t[i] = a.outMax;
    }

    for (int i = 0; i <= (a.inMax - a.inMin); ++i) {
        float outVal = float(a.outMin) + float(a.outMax - a.outMin) *
          powf(float(i) / float(a.inMax - a.inMin), 1.0f / a.gamma);
        t[i + a.inMin] = iclamp(outVal);
    }
}

void dump(int ch, uint8_t t[256]) {
    for (int i = 0; i < 256; ++i)
        std::cout << ch << " " << i << ": " << (int)t[i] << "\n";
}

ColorMap::ColorMap(const LevelsAdjustments& adj, float strength) {
    uint8_t rgb[256];
    fillTable(rgb, adj.adj[3]);

    uint8_t ch[3][256];
    for (uint8_t c = 0; c < 3; ++c)
        fillTable(ch[c], adj.adj[c]);
    //dump(0, ch[0]);
    //dump(1, ch[1]);
    //dump(2, ch[2]);
    //dump(3, rgb);

    for (uint16_t i = 0; i < 256; ++i) {
        for (uint8_t c = 0; c < 3; ++c) {
            t[c][i][0] = 255; t[c][i][1] = 0; t[c][i][2] = 0; t[c][i][3] = 0;
            float val = rgb[ ch[c][i] ];
            val = i + (val - i) * strength;
            int v = iclamp(val);
            NSCAssert(v >= 0 && v <= 255, @"ColorMap::ColorMap v=%d", v);
            t[c][i][c + 1] = v;
        }
    }
}

+ (TRColorMap*) newWithInput:(CIImage*)inputImage map:(ColorMap)theInputMap {
    TRColorMap* result = [[TRColorMap alloc] init];
    NSAssert(result, @"TRColorMap newWithInput result is nil");
    result.inputImage = inputImage;
    result.inputMap = theInputMap;
    return result;
}

- (CIImage*) outputImage {
    CIFilter* ch_r = [CIFilter filterWithName:@"CIColorMatrix"];
    NSAssert(ch_r, @"TRColorMap outputImage ch_r is nil");
    [ch_r setDefaults];
    [ch_r setValue:inputImage forKey:@"inputImage"];
    [ch_r setValue:[CIVector vectorWithX:1.0 Y:0.0 Z:0.0 W:0.0]
      forKey:@"inputRVector"];
    [ch_r setValue:[CIVector vectorWithX:1.0 Y:0.0 Z:0.0 W:0.0]
      forKey:@"inputGVector"];
    [ch_r setValue:[CIVector vectorWithX:1.0 Y:0.0 Z:0.0 W:0.0]
      forKey:@"inputBVector"];

    CIFilter* ch_g = [CIFilter filterWithName:@"CIColorMatrix"];
    NSAssert(ch_g, @"TRColorMap outputImage ch_g is nil");
    [ch_g setDefaults];
    [ch_g setValue:inputImage forKey:@"inputImage"];
    [ch_g setValue:[CIVector vectorWithX:0.0 Y:1.0 Z:0.0 W:0.0]
      forKey:@"inputRVector"];
    [ch_g setValue:[CIVector vectorWithX:0.0 Y:1.0 Z:0.0 W:0.0]
      forKey:@"inputGVector"];
    [ch_g setValue:[CIVector vectorWithX:0.0 Y:1.0 Z:0.0 W:0.0]
      forKey:@"inputBVector"];

    CIFilter* ch_b = [CIFilter filterWithName:@"CIColorMatrix"];
    NSAssert(ch_b, @"TRColorMap outputImage ch_b is nil");
    [ch_b setDefaults];
    [ch_b setValue:inputImage forKey:@"inputImage"];
    [ch_b setValue:[CIVector vectorWithX:0.0 Y:0.0 Z:1.0 W:0.0]
      forKey:@"inputRVector"];
    [ch_b setValue:[CIVector vectorWithX:0.0 Y:0.0 Z:1.0 W:0.0]
      forKey:@"inputGVector"];
    [ch_b setValue:[CIVector vectorWithX:0.0 Y:0.0 Z:1.0 W:0.0]
      forKey:@"inputBVector"];

    const ColorMap& f = inputMap;
    CIImage* i_r = [CIImage
      imageWithBitmapData:[NSData dataWithBytes:f.t[0] length:256 * 4]
      bytesPerRow:256 * 4 size:CGSizeMake(256, 1) format:kCIFormatARGB8
      colorSpace:nil];
    NSAssert(i_r, @"TRColorMap outputImage i_r is nil");

    CIImage* i_g = [CIImage
      imageWithBitmapData:[NSData dataWithBytes:f.t[1] length:256 * 4]
      bytesPerRow:256 * 4 size:CGSizeMake(256, 1) format:kCIFormatARGB8
      colorSpace:nil];
    NSAssert(i_g, @"TRColorMap outputImage i_g is nil");

    CIImage* i_b = [CIImage
      imageWithBitmapData:[NSData dataWithBytes:f.t[2] length:256 * 4]
      bytesPerRow:256 * 4 size:CGSizeMake(256, 1) format:kCIFormatARGB8
      colorSpace:nil];
    NSAssert(i_b, @"TRColorMap outputImage i_b is nil");

    CIFilter* c_r = [CIFilter filterWithName:@"CIColorMap"];
    NSAssert(c_r, @"TRColorMap outputImage c_r is nil");
    [c_r setDefaults];
    [c_r setValue:ch_r.outputImage forKey:@"inputImage"];
    [c_r setValue:i_r forKey:@"inputGradientImage"];

    CIFilter* c_g = [CIFilter filterWithName:@"CIColorMap"];
    NSAssert(c_g, @"TRColorMap outputImage c_g is nil");
    [c_g setDefaults];
    [c_g setValue:ch_g.outputImage forKey:@"inputImage"];
    [c_g setValue:i_g forKey:@"inputGradientImage"];

    CIFilter* c_b = [CIFilter filterWithName:@"CIColorMap"];
    NSAssert(c_b, @"TRColorMap outputImage c_b is nil");
    [c_b setDefaults];
    [c_b setValue:ch_b.outputImage forKey:@"inputImage"];
    [c_b setValue:i_b forKey:@"inputGradientImage"];

    CIFilter* c_rg = [CIFilter filterWithName:@"CIMaximumCompositing"];
    NSAssert(c_rg, @"TRColorMap outputImage c_rg is nil");
    [c_rg setDefaults];
    [c_rg setValue:c_g.outputImage forKey:@"inputImage"];
    [c_rg setValue:c_r.outputImage forKey:@"inputBackgroundImage"];

    CIFilter* rgb = [CIFilter filterWithName:@"CIMaximumCompositing"];
    NSAssert(rgb, @"TRColorMap outputImage rgb is nil");
    [rgb setDefaults];
    [rgb setValue:c_rg.outputImage forKey:@"inputImage"];
    [rgb setValue:c_b.outputImage forKey:@"inputBackgroundImage"];

    CIImage* result = rgb.outputImage;
    NSAssert(result, @"TRColorMap outputImage result is nil");
    return result;
}

- (void)setNilValueForKey:(NSString*)key {
    DDLogVerbose(@"TRColorMap setNilValueForKey %@", key);
    if ([key isEqualToString:@"inputMap"]) {
        inputMap = ColorMap();
    } else {
        [super setNilValueForKey:key];
    }
}
@end
