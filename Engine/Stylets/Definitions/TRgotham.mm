#import "TRStylet.h"

using tr::util::Spline;

@implementation TRgotham
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.gotham"
      name:@"Metropolis" group:@"Clones" code:@"Mt"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Effect Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1],
          nil];
    }
    return self;
}

- (CIImage*) applyTo:(CIImage*)input {
    TRGreyMix* redbw = [TRGreyMix newWithInput:input
      r:[NSNumber numberWithFloat:1] g:[NSNumber numberWithFloat:0]
      b:[NSNumber numberWithFloat:0]];

    Spline rgb1, r1, g1, b1;
    rgb1.addKnot(Spline::Knot(0, 0) / 255.0);
    rgb1.addKnot(Spline::Knot(128, 71) / 255.0);
    rgb1.addKnot(Spline::Knot(226, 211) / 255.0);
    rgb1.addKnot(Spline::Knot(255, 255) / 255.0);

    TRCurves* curve1 = [TRCurves newWithInput:redbw.outputImage rgb:rgb1];

    r1.addKnot(Spline::Knot(0, 0) / 255.0);
    r1.addKnot(Spline::Knot(51, 47) / 255.0);
    r1.addKnot(Spline::Knot(128, 128) / 255.0);
    r1.addKnot(Spline::Knot(202, 208) / 255.0);
    r1.addKnot(Spline::Knot(255, 255) / 255.0);

    g1.addKnot(Spline::Knot(0, 0) / 255.0);
    g1.addKnot(Spline::Knot(51, 47) / 255.0);
    g1.addKnot(Spline::Knot(127, 127) / 255.0);
    g1.addKnot(Spline::Knot(204, 208) / 255.0);
    g1.addKnot(Spline::Knot(255, 255) / 255.0);

    b1.addKnot(Spline::Knot(0, 0) / 255.0);
    b1.addKnot(Spline::Knot(43, 53) / 255.0);
    b1.addKnot(Spline::Knot(128, 128) / 255.0);
    b1.addKnot(Spline::Knot(228, 216) / 255.0);
    b1.addKnot(Spline::Knot(255, 255) / 255.0);

    Spline ident = Spline::ident();
    TRCurves* curve2 = [TRCurves newWithInput:curve1.outputImage rgb:ident
      r:r1 g:g1 b:b1];

    return curve2.outputImage;
}
@end
