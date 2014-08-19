#import "TRStylet.h"

@implementation TRfadedneutral
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.fadedneutral"
      name:@"Fade to Gray" group:@"Vintage Color" code:@"Fn"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1.0],
          nil];
    }
    return self;
}
- (CIImage*) applyTo:(CIImage*)input {
    LevelsAdjustments adj;
    adj.adj[3].outMin = 76;
    adj.adj[3].outMax = 235;
    TRLevels* levels1 = [TRLevels newWithInput:input levels:adj];
    return levels1.outputImage;
}
@end

