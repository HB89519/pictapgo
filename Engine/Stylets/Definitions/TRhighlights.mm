#include "TRStylet.h"

@implementation TRhighlights
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.highlights"
      name:@"Highlights" group:@"Basic Adjustments" code:@"Hl"];
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
    NSAssert(filt, @"TRhighlights applyTo filt is nil");
    [filt setDefaults];
    [filt setValue:input forKey:@"inputImage"];
    //[filt setValue:@0 forKey:@"inputRadius"];  // undocumented

    // Note to future self: for no change set highlights=1.0, shadows=0.0
    [filt setValue:@0.7f forKey:@"inputHighlightAmount"];
    //[filt setValue:@0.0001f forKey:@"inputShadowAmount"];

    NSAssert(input, @"TRhighlights input is nil");

    CIImage* result = filt.outputImage;
    NSAssert(result, @"TRhighlights applyTo result is nil for filt %@", filt);
    return result;
}
@end

