#include "TRStylet.h"

@implementation TRlightsout
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.lightsout"
      name:@"Lights Out" group:@"Basic Adjustments" code:@"D"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1.0],
          nil];
    }
    return self;
}
- (CIImage*) applyTo:(CIImage*)input {
    TRBlend* blend = [TRBlend newWithInput:input background:input
      mode:MULTIPLY strength:[NSNumber numberWithFloat:1.0]];
    return blend.outputImage;
}
@end

