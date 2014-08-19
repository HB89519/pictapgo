#import "TRStylet.h"

@implementation TRautocolor
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.autocolor"
      name:@"Auto Color" group:@"Basics" code:@"M"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1],
          nil];
    }
    return self;
}
- (CIImage*) applyTo:(CIImage*)input {
    TRAutoColor* al = [TRAutoColor newWithInput:input];
    return al.outputImage;
}
@end
