#import "TRStylet.h"

@implementation TRequalize
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.equalize"
      name:@"Equalize" group:@"Basics" code:@"Q"];
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
    TREqualize* al = [TREqualize newWithInput:grey.outputImage];
    TRBlend* blend = [TRBlend newWithInput:input background:al.outputImage mode:COLOR];
    return blend.outputImage;
}
@end
