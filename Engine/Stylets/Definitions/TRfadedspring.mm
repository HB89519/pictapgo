#import "TRStylet.h"

@implementation TRfadedspring
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.fadedspring"
      name:@"Fade to Spring" group:@"Vintage Color" code:@"Fv"];
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
    adj.adj[0].outMin = 16;
    adj.adj[0].outMax = 255;
    adj.adj[0].gamma = 1.2;
    adj.adj[1].outMin = 62;
    adj.adj[1].outMax = 251;
    adj.adj[1].gamma = 0.86;
    adj.adj[2].outMin = 0;
    adj.adj[2].outMax = 213;
    TRLevels* levels1 = [TRLevels newWithInput:input levels:adj];

    return levels1.outputImage;
}
@end

