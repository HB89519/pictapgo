#import "TRStylet.h"

static int ddLogLevel = LOG_LEVEL_INFO;

using tr::util::Spline;

@interface TRcoolasacucumber_extras : NSObject {
    @package
    TRCurves* curve;
}
@end

@implementation TRcoolasacucumber_extras
- (id) init {
    TRUNUSED CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    const Spline ident = Spline::ident();
    Spline r, b;
    r.addKnot(Spline::Knot(0, 0) / 255.0);
    r.addKnot(Spline::Knot(146, 131) / 255.0);
    r.addKnot(Spline::Knot(255, 255) / 255.0);
    b.addKnot(Spline::Knot(0, 0) / 255.0);
    b.addKnot(Spline::Knot(112, 131) / 255.0);
    b.addKnot(Spline::Knot(255, 255) / 255.0);

    curve = [TRCurves newWithInput:nil rgb:ident r:r g:ident b:b];
    TRUNUSED CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    DDLogVerbose(@"TRcoolasacucumber_extras init took %0.3f seconds", end - start);

    return self;
}
- (id) copyWithZone:(NSZone*)zone {
    return self;
}
@end

@implementation TRcoolasacucumber
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.coolasacucumber"
      name:@"Cool It Down" group:@"Basic Adjustments" code:@"C"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1.0],
          nil];
    }
    return self;
}
- (CIImage*) applyTo:(CIImage*)input {
    TRcoolasacucumber_extras* extras = [TRStylet preflightObjectForIdent:self.ident];
    if (!extras) {
        extras = [[TRcoolasacucumber_extras alloc] init];
        [TRStylet setPreflightObject:extras forIdent:self.ident];
    }

    TRCurves* curve = [extras->curve copy];
    curve.inputImage = input;
    return curve.outputImage;
}
@end
