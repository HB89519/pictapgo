#import "TRStylet.h"

using tr::util::Spline;

@implementation TRpoolparty
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.poolparty"
      name:@"Pool Party" group:@"Vintage Color" code:@"Pt"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1.0],
          [TRNumberKnob newKnobIdentifiedBy:@"crosstweak" named:@"Cross-Tweak"
            value:100 uiMin:0 uiMax:200 actualMin:0 actualMax:2.0],
          [TRNumberKnob newKnobIdentifiedBy:@"desatamount" named:@"Funky Desaturation"
            value:100 uiMin:0 uiMax:200 actualMin:0 actualMax:0.8],
          [TRNumberKnob newKnobIdentifiedBy:@"colorfade" named:@"Color Fade"
            value:100 uiMin:0 uiMax:200 actualMin:0 actualMax:2.0],
          nil];
    }
    return self;
}
- (CIImage*) applyTo:(CIImage*)input {
    Spline rgb, r1, g1, b1;
    rgb.addKnot(Spline::Knot(0, 0) / 255.0);
    rgb.addKnot(Spline::Knot(29,29) / 255.0);
    rgb.addKnot(Spline::Knot(155,183) / 255.0);
    rgb.addKnot(Spline::Knot(246,250) / 255.0);
    rgb.addKnot(Spline::Knot(255,255) / 255.0);
    r1.addKnot(Spline::Knot(0, 0) / 255.0);
    r1.addKnot(Spline::Knot(83,38) / 255.0);
    r1.addKnot(Spline::Knot(142,138) / 255.0);
    r1.addKnot(Spline::Knot(185,186) / 255.0);
    r1.addKnot(Spline::Knot(231,241) / 255.0);
    r1.addKnot(Spline::Knot(255,255) / 255.0);
    g1.addKnot(Spline::Knot(0,0) / 255.0);
    g1.addKnot(Spline::Knot(33,32) / 255.0);
    g1.addKnot(Spline::Knot(104,110) / 255.0);
    g1.addKnot(Spline::Knot(178,169) / 255.0);
    g1.addKnot(Spline::Knot(255,195) / 255.0);
    b1.addKnot(Spline::Knot(0,0) / 255.0);
    b1.addKnot(Spline::Knot(37,56) / 255.0);
    b1.addKnot(Spline::Knot(213,195) / 255.0);
    b1.addKnot(Spline::Knot(255,255) / 255.0);
    TRCurves* curve = [TRCurves newWithInput:input rgb:rgb r:r1 g:g1 b:b1];
    [curve setStrength:[self valueForKnob:@"crosstweak"]];
    
    TRGreyMix* greymix1 = [TRGreyMix newWithInput:curve.outputImage];
    
    TRBlend* desatblend = [TRBlend newWithInput:greymix1.outputImage
      background:curve.outputImage mode:NORMAL
      strength:[self valueForKnob:@"desatamount"]];
    
    LevelsAdjustments adj1;
    adj1.adj[0].outMin = 37;
    adj1.adj[0].outMax = 255;
    adj1.adj[2].outMin = 0;
    adj1.adj[2].outMax = 215;
    TRLevels* levels1 = [TRLevels newWithInput:desatblend.outputImage
      levels:adj1 strength:[self valueForKnob:@"colorfade"]];
      
    return levels1.outputImage;
}
@end


