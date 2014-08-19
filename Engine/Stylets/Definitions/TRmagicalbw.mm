#import "TRStylet.h"

using tr::util::Spline;

@implementation TRmagicalbw
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.magicalbw"
      name:@"Alabaster" group:@"Black and White" code:@"Mg"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"intensity" named:@"Intensity"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1.0],
          [TRNumberKnob newKnobIdentifiedBy:@"glow" named:@"Glow"
            value:100 uiMin:0 uiMax:200 actualMin:0 actualMax:0.008],
          [TRNumberKnob newKnobIdentifiedBy:@"contrast" named:@"Contrast"
            value:100 uiMin:0 uiMax:200 actualMin:0 actualMax:2.0],
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1.0],
          nil];
    }
    return self;
}
- (CIImage*) applyTo:(CIImage*)input {
    TRGreyMix* redbw = [TRGreyMix newWithInput:input r:[NSNumber numberWithFloat:1]
      g:[NSNumber numberWithFloat:0] b:[NSNumber numberWithFloat:0]];

    TRBlur* blur1 = [TRBlur newWithInput:redbw.outputImage
      radius:[self valueForKnob:@"glow"]];

    TRGreyMix* normalbw = [TRGreyMix newWithInput:input];

    TRBlend* blurblend = [TRBlend newWithInput:blur1.outputImage
      background:normalbw.outputImage mode:SOFT_LIGHT
      strength:[self valueForKnob:@"contrast"]];

    const Spline ident = Spline::ident();
    Spline c;
    c.addKnot(Spline::Knot(0, 0) / 255.0);
    c.addKnot(Spline::Knot(112, 112) / 255.0);
    c.addKnot(Spline::Knot(166, 166) / 255.0);
    c.addKnot(Spline::Knot(230, 236) / 255.0);
    TRCurves* curve = [TRCurves newWithInput:blurblend.outputImage rgb:c];

    TRBlend* intensityblend = [TRBlend newWithInput:curve.outputImage
      background:normalbw.outputImage mode:NORMAL
      strength:[self valueForKnob:@"intensity"]];

    return intensityblend.outputImage;
}
@end

