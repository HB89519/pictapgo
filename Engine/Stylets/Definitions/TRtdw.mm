#import "TRStylet.h"

@implementation TRtdw
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.tdw"
      name:@"Dream World" group:@"Modern Color" code:@"Dw"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"glow" named:@"Glow amount"
            value:100 uiMin:0 uiMax:200 actualMin:0 actualMax:0.003],
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1.0],
          nil];
    }
    return self;
}
- (CIImage*) applyTo:(CIImage*)input {
    TRBlur* glow = [TRBlur newWithInput:input radius:[self valueForKnob:@"glow"]];
    TRBlend* blend = [TRBlend newWithInput:glow.outputImage background:input
      mode:OVERLAY strength:[NSNumber numberWithFloat:0.7]];
    return blend.outputImage;
}
@end

