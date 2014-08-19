#import "TRStylet.h"

@implementation TRautocontrast
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.autocontrast"
      name:@"Auto Contrast" group:@"Basics" code:@"N"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1],
          nil];
    }
    return self;
}
- (CIImage*) applyTo:(CIImage*)input {
    TRGreyMix* grey = [TRGreyMix newWithInput:input];
    TRAutoColor* al = [TRAutoColor newWithInput:grey.outputImage];
    TRBlend* blend = [TRBlend newWithInput:input background:al.outputImage mode:COLOR];
    return blend.outputImage;
}
@end
