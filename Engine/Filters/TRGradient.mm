#import "TRFilter.h"

@implementation TRGradient
@synthesize inputImage;
@synthesize inputRadius;
@synthesize masterSize;

+ (TRGradient*) newWithInput:(CIImage*)inputImage radius:(NSNumber*)radius 
  masterSize:(CGSize)masterSize {
    TRGradient* result = [[TRGradient alloc] init];
    NSAssert(result, @"TRGradient newWithInput result is nil");
    result.inputImage = inputImage;
    result.inputRadius = radius;
    result.masterSize = masterSize;
    return result;
}

- (CIImage*) outputImage {
    CGSize size = inputImage.extent.size;

    float radius = sqrt(size.width * size.width + size.height * size.height) / 2.0;
    radius *= [inputRadius floatValue];

    CIFilter* gradient = [CIFilter filterWithName:@"CIRadialGradient"];
    NSAssert(gradient, @"TRGradient outputImage gradient is nil");
    [gradient setDefaults];
    [gradient setValue:[CIVector vectorWithX:size.width/2 Y:size.height / 2]
      forKey:@"inputCenter"];
    [gradient setValue:[NSNumber numberWithFloat:0] forKey:@"inputRadius0"];
    [gradient setValue:[NSNumber numberWithFloat:radius] forKey:@"inputRadius1"];
    [gradient setValue:[CIColor colorWithRed:1 green:1 blue:1] forKey:@"inputColor0"];
    [gradient setValue:[CIColor colorWithRed:0 green:0 blue:0] forKey:@"inputColor1"];

    CIFilter* crop = [CIFilter filterWithName:@"CICrop"];
    NSAssert(crop, @"TRGradient outputImage crop is nil");
    [crop setDefaults];
    [crop setValue:gradient.outputImage forKey:@"inputImage"];
    [crop setValue:[CIVector vectorWithX:0 Y:0 Z:size.width W:size.height]
      forKey:@"inputRectangle"];

    CIImage* result = crop.outputImage;
    NSAssert(result, @"TRGradient outputImage result is nil");
    return result;
}

@end
