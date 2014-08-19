#import "TRStylet.h"

@implementation TRemptystylet
- (id) init {
    self = [super initWithIdent:EMPTY_STYLET_IDENT
      name:@"Empty" group:@"Basics" code:@"Zz"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1],
          nil];
    }
    return self;
}
- (CIImage*) applyTo:(CIImage*)input {
    return input;
}
@end


