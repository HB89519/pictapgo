#import "TRStylet.h"

@implementation TRlightson
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.lightson"
      name:@"Lights On" group:@"Basic Adjustments" code:@"L"];
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
      mode:SCREEN strength:[NSNumber numberWithFloat:1.0]];
    return blend.outputImage;
}
@end

