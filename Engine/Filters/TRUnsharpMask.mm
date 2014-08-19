#import "TRFilter.h"

static int ddLogLevel = LOG_LEVEL_INFO;

@implementation TRUnsharpMask
@synthesize inputImage;
@synthesize inputRadius;
@synthesize inputAmount;

- (CIImage*) outputImage {
    const CGSize inputSize = inputImage.extent.size;

    CGSize sz = inputImage.extent.size;
    CGFloat preScale = 1.0, postScale = 1.0;
    CGFloat actualRadius = scaledRadius(sz, inputRadius.floatValue);
    while (sz.width > 1024 || sz.height > 1024 || actualRadius > 100.0) {
        sz.width /= 2.0;
        sz.height /= 2.0;
        preScale /= 2.0;
        postScale *= 2.0;
        actualRadius /= 2.0;
    }

    DDLogVerbose(@"TRUnsharpMask radius %@, size (%.1f,%.1f) working size (%.1fx%.1f)",
      inputRadius, inputSize.width, inputSize.height, sz.width, sz.height);

    // Extend the canvas by duplicating the edge pixels
    CIFilter* extend = [CIFilter filterWithName:@"CIAffineClamp"];
    NSAssert(extend, @"TRUnsharpMask outputImage extend is nil");
    [extend setDefaults];
    [extend setValue:inputImage forKey:@"inputImage"];
    [extend setValue:[NSValue valueWithBytes:&CGAffineTransformIdentity
      objCType:@encode(CGAffineTransform)] forKey:@"inputTransform"];

    CIImage* canvas = extend.outputImage;
    if (sz.width != inputSize.width || sz.height != inputSize.height) {
        CGAffineTransform downscale = CGAffineTransformMakeScale(preScale, preScale);
        canvas = [canvas imageByApplyingTransform:downscale];
    }
    
    CIFilter* usm = [CIFilter filterWithName:@"CIUnsharpMask"];
    NSAssert(usm, @"TRUnsharpMask outputImage usm is nil");
    [usm setDefaults];
    [usm setValue:canvas forKey:@"inputImage"];
    [usm setValue:[NSNumber numberWithFloat:actualRadius] forKey:@"inputRadius"];
    [usm setValue:inputAmount forKey:@"inputIntensity"];

    CIImage* upsize = usm.outputImage;
    
    if (inputSize.width != sz.width || inputSize.height != sz.height) {
        CGAffineTransform upscale = CGAffineTransformMakeScale(
          postScale, postScale);
        upsize = [upsize imageByApplyingTransform:upscale];
    }

    CIImage* crop = [upsize imageByCroppingToRect:
      CGRectMake(0, 0, inputSize.width, inputSize.height)];
    NSAssert(crop, @"TRUnsharpMask outputImage crop is nil");

    return crop;
}

+ (TRUnsharpMask*) newWithInput:(CIImage*)inputImage radius:(NSNumber*)inputRadius
  amount:(NSNumber*)inputAmount
{
    TRUnsharpMask* result = [[TRUnsharpMask alloc] init];
    NSAssert(result, @"TRUnsharpMask newWithInput result is nil");
    result.inputImage = inputImage;
    result.inputRadius = inputRadius;
    result.inputAmount = inputAmount;
    return result;
}

@end
