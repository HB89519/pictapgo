#import "TRStylet.h"

@implementation TRboxblur
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.boxblur"
      name:@"Box Blur" group:@"Basic Adjustments" code:@"#"];
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
    NSAssert(clamp, @"TRboxblur clamp is nil");
    [clamp setDefaults];
    [clamp setValue:input forKey:@"inputImage"];
    [clamp setValue:[NSValue valueWithBytes:&CGAffineTransformIdentity
      objCType:@encode(CGAffineTransform)] forKey:@"inputTransform"];
    
    CIFilter* blur = [CIFilter filterWithName:@"CIBoxBlur"];
    NSAssert(blur, @"TRboxblur blur is nil");
    [blur setDefaults];
    [blur setValue:clamp.outputImage forKey:@"inputImage"];
    [blur setValue:[self actualStrength] forKey:@"inputRadius"];
    
    CIFilter* crop = [CIFilter filterWithName:@"CISourceInCompositing"];
    NSAssert(crop, @"TRboxblur crop is nil");
    [crop setDefaults];
    [crop setValue:blur.outputImage forKey:@"inputImage"];
    [crop setValue:input forKey:@"inputBackgroundImage"];

    CIImage* result = crop.outputImage;
    NSAssert(result, @"TRboxblur result is nil");
    return result;
}
@end
