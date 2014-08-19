#import "TRStylet.h"

using tr::util::Spline;

@implementation TRsimplebw
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.simplebw"
      name:@"Simple BW" group:@"Black and White" code:@"Sb"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1],
          nil];
    }
    return self;
}
- (CIImage*) applyTo:(CIImage*)input {
    TRGreyMix* desat = [TRGreyMix newWithInput:input];

    return desat.outputImage;
}
@end
