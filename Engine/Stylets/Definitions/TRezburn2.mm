#import "TRStylet.h"

static int ddLogLevel = LOG_LEVEL_INFO;

using tr::util::Spline;

@interface TRezburn2_extras : NSObject {
@package
    TRCurves* curves;
}
@end

@implementation TRezburn2_extras
- (id) init {
    TRUNUSED CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();

    Spline c1;
    c1.addKnot(Spline::Knot(0, 64) / 255.0);
    c1.addKnot(Spline::Knot(31, 96) / 255.0);
    c1.addKnot(Spline::Knot(56, 113) / 255.0);
    c1.addKnot(Spline::Knot(81, 155) / 255.0);
    c1.addKnot(Spline::Knot(106, 188) / 255.0);
    c1.addKnot(Spline::Knot(130, 212) / 255.0);
    c1.addKnot(Spline::Knot(155, 230) / 255.0);
    c1.addKnot(Spline::Knot(180, 240) / 255.0);
    c1.addKnot(Spline::Knot(205, 247) / 255.0);
    c1.addKnot(Spline::Knot(230, 252) / 255.0);
    c1.addKnot(Spline::Knot(255, 255) / 255.0);

    curves = [TRCurves newWithInput:nil rgb:c1];
    [curves setStrength:@1.1];
    [curves setColorCubeSize:32];

    TRUNUSED CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    DDLogVerbose(@"TRezburn2_extras init took %0.3f seconds", end - start);

    return self;
}
- (id) copyWithZone:(NSZone*)zone {
    return self;
}
@end

@implementation TRezburn2
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.ezburn2"
      name:@"SloBurn" group:@"Optical and Lens Effects" code:@"Vg"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1],
          [TRNumberKnob newKnobIdentifiedBy:@"safearea" named:@"Vignette Size"
            value:0 uiMin:-100 uiMax:100 actualMin:0 actualMax:2.2],
          nil];
    }
    return self;
}

- (CIImage*) applyTo:(CIImage*)input {
    TRezburn2_extras* extras = [TRStylet preflightObjectForIdent:self.ident];
    if (!extras) {
        extras = [[TRezburn2_extras alloc] init];
        [TRStylet setPreflightObject:extras forIdent:self.ident];
    }
    NSAssert(extras, @"TRezburn2_extras is nil");

    TRGradient* gradient = [TRGradient newWithInput:input radius:[NSNumber numberWithFloat:1.0]
      masterSize:self.masterSize];
    NSAssert(gradient, @"TRezburn2 gradient is nil");

    TRCurves* curves = [extras->curves copy];
    NSAssert(gradient, @"TRezburn2 curves is nil");
    curves.inputImage = gradient.outputImage;

    TRBlend* finalblend = [TRBlend newWithInput:curves.outputImage background:input
      mode:MULTIPLY];
    NSAssert(finalblend, @"TRezburn2 finalblend is nil");

    CIImage* result = finalblend.outputImage;
    NSAssert(result, @"TRezburn2 result is nil");
    return result;
}
@end
