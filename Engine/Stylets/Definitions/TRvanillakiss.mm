#import "TRStylet.h"

using tr::util::Spline;

@implementation TRvanillakiss
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.vanillakiss"
      name:@"Vanilla Kiss" group:@"Vintage Color" code:@"Vk"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1.0],
          nil];
    }
    return self;
}
- (CIImage*) applyTo:(CIImage*)input {
    Spline rgb, r, g, b;
    rgb = Spline::ident();
    r.addKnot(Spline::Knot(0, 0) / 255.0);
    r.addKnot(Spline::Knot(87, 88) / 255.0);
    r.addKnot(Spline::Knot(223, 243) / 255.0);
    r.addKnot(Spline::Knot(255, 255) / 255.0);
    g.addKnot(Spline::Knot(0, 0) / 255.0);
    g.addKnot(Spline::Knot(98, 98) / 255.0);
    g.addKnot(Spline::Knot(205, 225) / 255.0);
    g.addKnot(Spline::Knot(255, 255) / 255.0);
    b.addKnot(Spline::Knot(0, 20) / 255.0);
    b.addKnot(Spline::Knot(255, 241) / 255.0);
    TRCurves* curves1 = [TRCurves newWithInput:input rgb:rgb r:r g:g b:b];

    return curves1.outputImage;
}
@end

