#import "TRStylet.h"

@implementation TRoldglory
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.oldglory"
      name:@"Old Glory" group:@"Modern Color" code:@"Gl"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1.0],
          nil];
    }
    return self;
}
- (CIImage*) applyTo:(CIImage*)input {
    TRGreyMix* greymix = [TRGreyMix newWithInput:input];
    TRBlend* finalblend = [TRBlend newWithInput:greymix.outputImage
      background:input mode:HARD_LIGHT];
    return finalblend.outputImage;
}
@end

