#import "TRFilter.h"

@implementation TRGreyMix
@synthesize inputImage;
@synthesize inputVector;

+ (TRGreyMix*) newWithInput:(CIImage*)inputImage mix:(CIVector*)mix {
    TRGreyMix* result = [[TRGreyMix alloc] init];
    NSAssert(result, @"TRGreyMix newWithInput result is nil");
    result.inputImage = inputImage;
    result.inputVector = mix;
    return result;
}

+ (TRGreyMix*) newWithInput:(CIImage*)inputImage
  r:(NSNumber*)r g:(NSNumber*)g b:(NSNumber*)b
{
    CIVector* mix = [CIVector vectorWithX:[r floatValue]
      Y:[g floatValue] Z:[b floatValue]];
    return [TRGreyMix newWithInput:inputImage mix:mix];
}

+ (TRGreyMix*) newWithInput:(CIImage*)inputImage {
    CIVector* mix = [CIVector vectorWithX:.3 Y:.59 Z:.11];
    return [TRGreyMix newWithInput:inputImage mix:mix];
}

- (CIImage*) outputImage {
    CIVector* chVector = [CIVector vectorWithX:inputVector.X
      Y:inputVector.Y Z:inputVector.Z];
    CIVector* biasVector = [CIVector vectorWithX:inputVector.W
      Y:inputVector.W Z:inputVector.W];

    CIFilter* grey = [CIFilter filterWithName:@"CIColorMatrix"];
    NSAssert(grey, @"TRGreyMix outputImage grey is nil");
    [grey setDefaults];
    [grey setValue:inputImage forKey:@"inputImage"];
    [grey setValue:chVector forKey:@"inputRVector"];
    [grey setValue:chVector forKey:@"inputGVector"];
    [grey setValue:chVector forKey:@"inputBVector"];
    [grey setValue:biasVector forKey:@"inputBiasVector"];

    CIImage* result = grey.outputImage;
    NSAssert(result, @"TRGreyMix outputImage result is nil");
    return result;
}

@end
