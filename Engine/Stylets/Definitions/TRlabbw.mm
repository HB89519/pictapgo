#import "TRStylet.h"

using tr::util::Spline;

@implementation TRlabbw
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.labbw"
      name:@"L*ab BW" group:@"Black and White" code:@"Lb"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1],
          nil];
    }
    return self;
}
- (CIImage*) applyTo:(CIImage*)input {
    TRLabGrey* desat = [TRLabGrey newWithInput:input];

    return desat.outputImage;
}
@end
