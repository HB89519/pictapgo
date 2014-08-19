#import "TRStylet.h"

@implementation TRgaussianblur
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.gaussianblur"
      name:@"Gaussian Blur" group:@"Basic Adjustments" code:@"#"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:10.0 uiMin:0.0 uiMax:100.0 actualMin:0 actualMax:100.0],
          nil];
    }
    return self;
}
- (CIImage*) applyTo:(CIImage*)input {
    CIFilter* clamp = [CIFilter filterWithName:@"CIAffineClamp"];
    NSAssert(clamp, @"TRgaussianblur applyTo clamp is nil");
    [clamp setDefaults];
    [clamp setValue:input forKey:@"inputImage"];
    [clamp setValue:[NSValue valueWithBytes:&CGAffineTransformIdentity
      objCType:@encode(CGAffineTransform)] forKey:@"inputTransform"];
    
    CIFilter* blur = [CIFilter filterWithName:@"CIGaussianBlur"];
    NSAssert(blur, @"TRgaussianblur applyTo blur is nil");
    [blur setDefaults];
    [blur setValue:clamp.outputImage forKey:@"inputImage"];
    [blur setValue:[self valueForKnob:@"inputRadius"] forKey:@"inputRadius"];
    
    CIFilter* crop = [CIFilter filterWithName:@"CISourceInCompositing"];
    NSAssert(crop, @"TRgaussianblur applyTo crop is nil");
    [crop setDefaults];
    [crop setValue:blur.outputImage forKey:@"inputImage"];
    [crop setValue:input forKey:@"inputBackgroundImage"];

    CIImage* result = crop.outputImage;
    NSAssert(result, @"TRgaussianblur applyTo result is nil");
    return result;
}
@end

