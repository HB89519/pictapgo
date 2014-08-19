#import "TRFilter.h"

@implementation TRChannelMix
@synthesize inputImage;
@synthesize inputRVector;
@synthesize inputGVector;
@synthesize inputBVector;
@synthesize inputBiasVector;

+ (TRChannelMix*) newWithInput:(CIImage*)inputImage
  r:(CIVector*)r g:(CIVector*)g b:(CIVector*)b
{
    return [TRChannelMix newWithInput:inputImage r:r g:g b:b
      bias:[CIVector vectorWithX:0 Y:0 Z:0 W:0]];
}

+ (TRChannelMix*) newWithInput:(CIImage*)inputImage
  r:(CIVector*)r g:(CIVector*)g b:(CIVector*)b bias:(CIVector*)bias
{
    TRChannelMix* result = [[TRChannelMix alloc] init];
    NSAssert(result, @"TRChannelMix newWithInput returned nil");
    result.inputImage = inputImage;
    result.inputRVector = r;
    result.inputGVector = g;
    result.inputBVector = b;
    result.inputBiasVector = bias;
    return result;
}

- (CIImage*) outputImage {
    CIFilter* mix = [CIFilter filterWithName:@"CIColorMatrix"];
    NSAssert(mix, @"TRChannelMix outputImage mix is nil");
    [mix setDefaults];
    [mix setValue:inputImage forKey:@"inputImage"];
    [mix setValue:inputRVector forKey:@"inputRVector"];
    [mix setValue:inputGVector forKey:@"inputGVector"];
    [mix setValue:inputBVector forKey:@"inputBVector"];
    [mix setValue:inputBiasVector forKey:@"inputBiasVector"];

    CIImage* result = mix.outputImage;
    NSAssert(result, @"TRChannelMix result is nil");
    return result;
}

@end
