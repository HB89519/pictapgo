#import "TRStylet.h"

static int ddLogLevel = LOG_LEVEL_INFO;

using tr::util::Spline;

@interface TRpc2_extras : NSObject {
@package
    TRHueSat* sat;
    TRCurves* curves;
}
@end

@implementation TRpc2_extras
- (id) init {
    TRUNUSED CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();

    HueSatAdjustments adj;
    adj.slices.push_back(
      HueSatAdjustments::Slice(0, 0, 0, 0, 0, -0.10, 0));
    sat = [TRHueSat newWithInput:nil hueSat:adj];

    Spline rgb, r, g, b;
    rgb.addKnot(Spline::Knot(0, 0) / 255.0);
    rgb.addKnot(Spline::Knot(44, 20) / 255.0);
    rgb.addKnot(Spline::Knot(117, 117) / 255.0);
    rgb.addKnot(Spline::Knot(198, 229) / 255.0);
    rgb.addKnot(Spline::Knot(255, 255) / 255.0);
    r.addKnot(Spline::Knot(0, 53) / 255.0);
    r.addKnot(Spline::Knot(130, 139) / 255.0);
    r.addKnot(Spline::Knot(255, 211) / 255.0);
    g.addKnot(Spline::Knot(0, 0) / 255.0);
    g.addKnot(Spline::Knot(19, 26) / 255.0);
    g.addKnot(Spline::Knot(113, 111) / 255.0);
    g.addKnot(Spline::Knot(203, 201) / 255.0);
    g.addKnot(Spline::Knot(255, 255) / 255.0);
    b.addKnot(Spline::Knot(0, 0) / 255.0);
    b.addKnot(Spline::Knot(85, 100) / 255.0);
    b.addKnot(Spline::Knot(187, 162) / 255.0);
    b.addKnot(Spline::Knot(255, 255) / 255.0);
    curves = [TRCurves newWithInput:nil rgb:rgb r:r g:g b:b];
    [curves setColorCubeSize:16];

    TRUNUSED CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    DDLogVerbose(@"TRpc2_extras init took %0.3f seconds", end - start);

    return self;
}
- (id) copyWithZone:(NSZone*)zone {
    return self;
}
@end

@implementation TRpc2
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.pc2"
      name:@"Crossroads" group:@"Basic Adjustments" code:@"Pk"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1.0],
          nil];
    }
    return self;
}
- (CIImage*) applyTo:(CIImage*)input {
    TRpc2_extras* extras = [TRStylet preflightObjectForIdent:self.ident];
    if (!extras) {
        extras = [[TRpc2_extras alloc] init];
        [TRStylet setPreflightObject:extras forIdent:self.ident];
    }

    TRHueSat* huesat = [extras->sat copy];
    huesat.inputImage = input;

    TRCurves* curve = [extras->curves copy];
    curve.inputImage = huesat.outputImage;

    return curve.outputImage;
}
@end
