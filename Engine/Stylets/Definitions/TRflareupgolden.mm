#import "TRStylet.h"

using tr::util::Spline;

@implementation TRflareupgolden
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.flareupgolden"
      name:@"Flare Up" group:@"Optical and Lens Effects" code:@"Fg"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1],
          [TRNumberKnob newKnobIdentifiedBy:@"flaresize" named:@"Flare Size"
            value:100 uiMin:0 uiMax:200 actualMin:0 actualMax:0.6],
          [TRNumberKnob newKnobIdentifiedBy:@"flareintensity" named:@"Flare Intensity"
            value:100 uiMin:0 uiMax:200 actualMin:0 actualMax:1.2],
          [TRNumberKnob newKnobIdentifiedBy:@"toningamount" named:@"Warmth"
            value:100 uiMin:0 uiMax:200 actualMin:0 actualMax:2],
          nil];
    }
    return self;
}

- (CIImage*) applyTo:(CIImage*)input {
    TRBlur* blur1 = [TRBlur newWithInput:input
      radius:[self valueForKnob:@"flaresize"]];

    Spline c1;
    c1.addKnot(Spline::Knot(0, 0) / 255.0);
    c1.addKnot(Spline::Knot(91,161) / 255.0);
    c1.addKnot(Spline::Knot(255, 255) / 255.0);
    
    TRCurves* midlift = [TRCurves newWithInput:blur1.outputImage rgb:c1];
    
    LevelsAdjustments l1;
    l1.adj[3].inMin = 128;
    l1.adj[3].inMax = 251;
    TRLevels* levels1 = [TRLevels newWithInput:midlift.outputImage levels:l1];
    
    TRBlur* blur2 = [TRBlur newWithInput:levels1.outputImage
      radius:[NSNumber numberWithFloat:0.132]];

    TRBlend* flareblend = [TRBlend newWithInput:blur2.outputImage background:input
      mode:SCREEN strength:[self valueForKnob:@"flareintensity"]];
    
    Spline iota = Spline::ident();
    Spline c2, c3;
    c2.addKnot(Spline::Knot(0, 0) / 255.0);
    c2.addKnot(Spline::Knot(131, 162) / 255.0);
    c2.addKnot(Spline::Knot(255, 255) / 255.0);
    c3.addKnot(Spline::Knot(0, 50) / 255.0);
    c3.addKnot(Spline::Knot(131, 94) / 255.0);
    c3.addKnot(Spline::Knot(255, 255) / 255.0);
    TRCurves* warmcurve = [TRCurves newWithInput:flareblend.outputImage
      rgb:iota r:c2 g:iota b:c3];
    [warmcurve setStrength:[self valueForKnob:@"toningamount"]];
    
    return warmcurve.outputImage;
}
@end

