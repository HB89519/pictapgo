#import "TRStylet.h"

@implementation TRfadedsummer
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.fadedsummer"
      name:@"Fade to Summer" group:@"Vintage Color" code:@"Fw"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1.0],
          [TRNumberKnob newKnobIdentifiedBy:@"colorfade" named:@"Color fade"
            value:100 uiMin:0 uiMax:200 actualMin:0 actualMax:2],
          [TRNumberKnob newKnobIdentifiedBy:@"lumafade" named:@"Contrast fade"
            value:100 uiMin:0 uiMax:200 actualMin:0 actualMax:2],
          nil];
    }
    return self;
}
- (CIImage*) applyTo:(CIImage*)input {
    LevelsAdjustments adj;
    adj.adj[3].gamma = 1.11;
    adj.adj[0].outMin = 90;
    adj.adj[0].outMax = 255;
    adj.adj[0].gamma = 0.95;
    adj.adj[1].outMin = 49;
    adj.adj[1].outMax = 255;
    adj.adj[1].gamma = 0.95;
    adj.adj[2].outMin = 0;
    adj.adj[2].outMax = 189;
    TRLevels* levels1 = [TRLevels newWithInput:input levels:adj];

    /*
    // XXX: with these two blends, certain highlights blow out and turn gray
    TRBlend* colorblend = [TRBlend newWithInput:levels1.outputImage
      background:input mode:COLOR strength:[self valueForKnob:@"colorfade"]];

    TRBlend* lumablend = [TRBlend newWithInput:levels1.outputImage
      background:colorblend.outputImage mode:LUMINOSITY
      strength:[self valueForKnob:@"lumafade"]];
    */
    
    return levels1.outputImage;
}
@end

