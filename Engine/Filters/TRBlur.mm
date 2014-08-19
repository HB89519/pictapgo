#import "TRFilter.h"

static int ddLogLevel = LOG_LEVEL_INFO;

@implementation TRBlur
@synthesize inputImage;
@synthesize inputRadius;

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

    DDLogVerbose(@"TRBlur radius %@, size (%.1f,%.1f) working size (%.1f,%.1f)",
      inputRadius, inputSize.width, inputSize.height, sz.width, sz.height);

    // Extend the canvas by duplicating the edge pixels
    CIFilter* extend = [CIFilter filterWithName:@"CIAffineClamp"];
    NSAssert(extend, @"TRBlur outputImage extend is nil");
    [extend setDefaults];
    [extend setValue:inputImage forKey:@"inputImage"];
    [extend setValue:[NSValue valueWithBytes:&CGAffineTransformIdentity
      objCType:@encode(CGAffineTransform)] forKey:@"inputTransform"];

    CIImage* canvas = extend.outputImage;
    NSAssert(canvas, @"TRBlur outputImage canvas is nil");
    if (sz.width != inputSize.width || sz.height != inputSize.height) {
        CGAffineTransform downscale = CGAffineTransformMakeScale(preScale, preScale);
        canvas = [canvas imageByApplyingTransform:downscale];
    }
    
    CIFilter* blur = [CIFilter filterWithName:@"CIGaussianBlur"];
    NSAssert(blur, @"TRBlur outputImage blur is nil");
    [blur setDefaults];
    [blur setValue:canvas forKey:@"inputImage"];
    [blur setValue:[NSNumber numberWithFloat:actualRadius] forKey:@"inputRadius"];

    CIImage* upsize = blur.outputImage;
    NSAssert(upsize, @"TRBlur outputImage upsize is nil");

    if (inputSize.width != sz.width || inputSize.height != sz.height) {
        CGAffineTransform upscale = CGAffineTransformMakeScale(
          postScale, postScale);
        upsize = [upsize imageByApplyingTransform:upscale];
        NSAssert(upsize, @"TRBlur outputImage transformed upsize is nil");
    }

    CIImage* crop = [upsize imageByCroppingToRect:
      CGRectMake(0, 0, inputSize.width, inputSize.height)];
    NSAssert(crop, @"TRBlur radius %@, size (%.1f,%.1f) working size (%.1f,%.1f) outputImage crop is nil",
      inputRadius, inputSize.width, inputSize.height, sz.width, sz.height);
    
    return crop;
}

+ (TRBlur*) newWithInput:(CIImage*)inputImage radius:(NSNumber*)inputRadius {
    TRBlur* result = [[TRBlur alloc] init];
    NSAssert(result, @"TRBlur newWithInput returned nil");
    result.inputImage = inputImage;
    result.inputRadius = inputRadius;
    return result;
}

@end
