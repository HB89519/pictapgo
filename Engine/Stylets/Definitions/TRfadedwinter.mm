#import "TRStylet.h"

@implementation TRfadedwinter
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.fadedwinter"
      name:@"Fade to Winter" group:@"Vintage Color" code:@"Fr"];
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
    adj.adj[3].gamma = 1.19;
    adj.adj[0].gamma = 1.12;
    adj.adj[2].outMin = 86;
    adj.adj[2].outMax = 185;
    TRLevels* levels1 = [TRLevels newWithInput:input levels:adj];
    
    return levels1.outputImage;
}
@end

