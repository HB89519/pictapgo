#include "TRStylet.h"

@implementation TRdotscreen
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.dotscreen"
      name:@"Paperboy" group:@"Basic Adjustments" code:@"Dh"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1.0],
          nil];
    }
    return self;
}

- (CIImage*) applyTo:(CIImage*)input {
    const CGSize sz = input.extent.size;
    const CGFloat scale = sqrt(sz.width * sz.width + sz.height * sz.height) / 150.0;
    CIFilter* filt = [CIFilter filterWithName:@"CIDotScreen"];
    NSAssert(filt, @"TRdotscreen applyTo filt is nil");
    [filt setDefaults];
    [filt setValue:input forKey:@"inputImage"];
    [filt setValue:[NSNumber numberWithFloat:scale] forKey:@"inputWidth"];
    [filt setValue:[NSNumber numberWithFloat:0.2] forKey:@"inputAngle"]; // radians

    CIImage* result = filt.outputImage;
    NSAssert(result, @"TRdotscreen applyTo result is nil");
    return result;
}
@end

