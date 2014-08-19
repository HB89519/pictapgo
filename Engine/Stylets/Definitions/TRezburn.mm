#import "TRStylet.h"

static int ddLogLevel = LOG_LEVEL_INFO;

using tr::util::Spline;

@interface TRezburn_extras : NSObject {
@package
    TRCurves* curves;
}
@end

@implementation TRezburn_extras
- (id) init {
    TRUNUSED CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();

    Spline c1;
    c1.addKnot(Spline::Knot(0, 96) / 255.0);
    c1.addKnot(Spline::Knot(19, 162) / 255.0);
    c1.addKnot(Spline::Knot(39, 196) / 255.0);
    c1.addKnot(Spline::Knot(141, 251) / 255.0);
    c1.addKnot(Spline::Knot(255, 255) / 255.0);

    curves = [TRCurves newWithInput:nil rgb:c1];
    [curves setStrength:@1.1];
    [curves setColorCubeSize:32];

    TRUNUSED CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    DDLogVerbose(@"TRezburn_extras init took %0.3f seconds", end - start);

    return self;
}
- (id) copyWithZone:(NSZone*)zone {
    return self;
}
@end

@implementation TRezburn
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.ezburn"
      name:@"EZ-Burn" group:@"Optical and Lens Effects" code:@"V"];
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
    TRezburn_extras* extras = [TRStylet preflightObjectForIdent:self.ident];
    if (!extras) {
        extras = [[TRezburn_extras alloc] init];
        [TRStylet setPreflightObject:extras forIdent:self.ident];
    }
    NSAssert(extras, @"TRezburn_extras is nil");

    TRGradient* gradient = [TRGradient newWithInput:input radius:[NSNumber numberWithFloat:1.0]
      masterSize:self.masterSize];
    NSAssert(gradient, @"TRezburn gradient is nil");

    TRCurves* curves = [extras->curves copy];
    NSAssert(gradient, @"TRezburn curves is nil");
    curves.inputImage = gradient.outputImage;

    TRBlend* finalblend = [TRBlend newWithInput:curves.outputImage background:input
      mode:LINEAR_BURN];
    NSAssert(finalblend, @"TRezburn finalblend is nil");

    CIImage* result = finalblend.outputImage;
    NSAssert(result, @"TRezburn result is nil");
    return result;
}
@end
