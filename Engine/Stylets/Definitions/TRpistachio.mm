#import "TRStylet.h"

using tr::util::Spline;

@implementation TRpistachio
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.pistachio"
      name:@"Pistachio" group:@"Vintage Color" code:@"Ps"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1],
          nil];
    }
    return self;
}
- (CIImage*) applyTo:(CIImage*)input {
    Spline ident = Spline::ident();
    Spline r, g, b;

    // r: 0,0; 70,79; 205,193; 255,255
    r.addKnot(Spline::Knot(0, 0) / 255.0);
    r.addKnot(Spline::Knot(70, 79) / 255.0);
    r.addKnot(Spline::Knot(205, 193) / 255.0);
    r.addKnot(Spline::Knot(255, 255) / 255.0);
    // g: 0,0; 92,82; 216,226; 255,255
    g.addKnot(Spline::Knot(0, 0) / 255.0);
    g.addKnot(Spline::Knot(92, 82) / 255.0);
    g.addKnot(Spline::Knot(216, 226) / 255.0);
    g.addKnot(Spline::Knot(255, 255) / 255.0);
    // b: 0,19; 255,234
    b.addKnot(Spline::Knot(0, 19) / 255.0);
    b.addKnot(Spline::Knot(255, 234) / 255.0);
    
    TRCurves* curve = [TRCurves newWithInput:input rgb:ident r:r g:g b:b];

    return curve.outputImage;
}
@end

