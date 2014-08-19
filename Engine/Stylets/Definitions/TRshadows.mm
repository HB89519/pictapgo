#include "TRStylet.h"

@implementation TRshadows
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.shadows"
      name:@"Shadows" group:@"Basic Adjustments" code:@"Sh"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1.0],
          nil];
    }
    return self;
}
- (CIImage*) applyTo:(CIImage*)input {
    CIFilter* filt = [CIFilter filterWithName:@"CIHighlightShadowAdjust"];
    NSAssert(filt, @"TRshadows applyTo filt is nil");
    [filt setDefaults];
    [filt setValue:input forKey:@"inputImage"];
    //[filt setValue:@0 forKey:@"inputRadius"];  // undocumented

    // Note to future self: for no change set highlights=1.0, shadows=0.0
    //[filt setValue:@0.9999f forKey:@"inputHighlightAmount"];
    [filt setValue:@0.9999f forKey:@"inputShadowAmount"];

    NSAssert(input, @"TRshadows input is nil");

    CIImage* result = filt.outputImage;
    NSAssert(result, @"TRshadows applyTo result is nil for filt %@", filt);
    return result;
}
@end

