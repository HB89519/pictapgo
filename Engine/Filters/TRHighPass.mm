#import "TRFilter.h"

@implementation TRHighPass
@synthesize inputImage;
@synthesize inputBlurredImage;
@synthesize inputBrightness;

+ (TRHighPass*) newWithInput:(CIImage*)inputImage
  blurredImage:(CIImage*)blurredImage brightness:(NSNumber*)brightness
{
    TRHighPass* result = [[TRHighPass alloc] init];
    NSAssert(result, @"TRHighPass newWithInput result is nil");
    result.inputImage = inputImage;
    result.inputBlurredImage = blurredImage;
    result.inputBrightness = brightness;
    return result;
}

+ (TRHighPass*) newWithInput:(CIImage*)inputImage
  blurredImage:(CIImage*)blurredImage {
    return [TRHighPass newWithInput:inputImage blurredImage:blurredImage
      brightness:[NSNumber numberWithFloat:0.5]];
}

- (CIImage*) outputImage {
    CIFilter* bg = [CIFilter filterWithName:@"CIColorMatrix"];
    NSAssert(bg, @"TRGreyMix outputImage bg is nil");
    CIFilter* fg = [CIFilter filterWithName:@"CIColorMatrix"];
    NSAssert(fg, @"TRGreyMix outputImage fg is nil");

    [bg setDefaults];
    [bg setValue:inputImage forKey:@"inputImage"];
    [bg setValue:[CIVector vectorWithX:0.5 Y:0 Z:0] forKey:@"inputRVector"];
    [bg setValue:[CIVector vectorWithX:0 Y:0.5 Z:0] forKey:@"inputGVector"];
    [bg setValue:[CIVector vectorWithX:0 Y:0 Z:0.5] forKey:@"inputBVector"];
    [bg setValue:[CIVector vectorWithX:0.5 Y:0.5 Z:0.5] forKey:@"inputBiasVector"];

    [fg setDefaults];
    [fg setValue:inputBlurredImage forKey:@"inputImage"];
    [fg setValue:[CIVector vectorWithX:0.5 Y:0 Z:0] forKey:@"inputRVector"];
    [fg setValue:[CIVector vectorWithX:0 Y:0.5 Z:0] forKey:@"inputGVector"];
    [fg setValue:[CIVector vectorWithX:0 Y:0 Z:0.5] forKey:@"inputBVector"];

    CIFilter* blend = [CIFilter filterWithName:@"CIDifferenceBlendMode"];
    NSAssert(blend, @"TRGreyMix outputImage blend is nil");
    [blend setDefaults];
    [blend setValue:bg.outputImage forKey:@"inputBackgroundImage"];
    [blend setValue:fg.outputImage forKey:@"inputImage"];

    CIFilter* hp = [CIFilter filterWithName:@"CIColorMatrix"];
    NSAssert(hp, @"TRGreyMix outputImage hp is nil");
    [hp setDefaults];
    [hp setValue:blend.outputImage forKey:@"inputImage"];
    [hp setValue:[CIVector vectorWithX:2.0 Y:0 Z:0] forKey:@"inputRVector"];
    [hp setValue:[CIVector vectorWithX:0 Y:2.0 Z:0] forKey:@"inputGVector"];
    [hp setValue:[CIVector vectorWithX:0 Y:0 Z:2.0] forKey:@"inputBVector"];
    [hp setValue:[CIVector vectorWithX:-0.5 Y:-0.5 Z:-0.5] forKey:@"inputBiasVector"];

    CIImage* result = hp.outputImage;
    NSAssert(result, @"TRGreyMix outputImage result is nil");
    return result;
}

@end
