#import "TRStylet.h"

static int ddLogLevel = LOG_LEVEL_INFO;

using tr::util::Spline;

@interface TRpluscontrast_extras : NSObject {
@package
    TRCurves* curve;
}
@end

@implementation TRpluscontrast_extras
- (id) init {
    TRUNUSED CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    Spline c;
    c.addKnot(Spline::Knot(0, 0) / 255.0);
    c.addKnot(Spline::Knot(13, 6) / 255.0);
    c.addKnot(Spline::Knot(240, 249) / 255.0);
    c.addKnot(Spline::Knot(255, 255) / 255.0);
    curve = [TRCurves newWithInput:nil rgb:c];
    TRUNUSED CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    DDLogVerbose(@"TRpluscontrast_extras init took %0.3f seconds", end - start);

    return self;
}
- (id) copyWithZone:(NSZone*)zone {
    return self;
}
@end

@implementation TRpluscontrast
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.pluscontrast"
      name:@"+ Contrast" group:@"Basic Adjustments" code:@"S"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1],
          nil];
    }
    return self;
}
- (CIImage*) applyTo:(CIImage*)input {
    TRpluscontrast_extras* extras = [TRStylet preflightObjectForIdent:self.ident];
    if (!extras) {
        extras = [[TRpluscontrast_extras alloc] init];
        [TRStylet setPreflightObject:extras forIdent:self.ident];
    }
    TRCurves* curve = [extras->curve copy];
    curve.inputImage = input;
    return curve.outputImage;
}
@end
