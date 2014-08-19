#import "TRStylet.h"

static int ddLogLevel = LOG_LEVEL_INFO;

using tr::util::Spline;

@interface TRportland_extras : NSObject {
@package
    TRCurves* curves;
    TRHueSat* sat;
}
@end

@implementation TRportland_extras
- (id) init {
    TRUNUSED CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();

    Spline rgb;
    rgb.addKnot(Spline::Knot(0, 18) / 255.0);
    rgb.addKnot(Spline::Knot(26, 30) / 255.0);
    rgb.addKnot(Spline::Knot(126, 129) / 255.0);
    rgb.addKnot(Spline::Knot(215, 215) / 255.0);
    rgb.addKnot(Spline::Knot(255, 231) / 255.0);
    curves = [TRCurves newWithInput:nil rgb:rgb];

    HueSatAdjustments adj;
    adj.slices.push_back(
      HueSatAdjustments::Slice(0, 0, 0, 0, 0, -.15, 0));
    sat = [TRHueSat newWithInput:nil hueSat:adj];

    TRUNUSED CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    DDLogVerbose(@"TRportland_extras init took %0.3f seconds", end - start);

    return self;
}
- (id) copyWithZone:(NSZone*)zone {
    return self;
}
@end

@implementation TRportland
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.portland"
      name:@"Portland" group:@"Basic Adjustments" code:@"Pr"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1.0],
          nil];
    }
    return self;
}
- (CIImage*) applyTo:(CIImage*)input {
    TRportland_extras* extras = [TRStylet preflightObjectForIdent:self.ident];
    if (!extras) {
        extras = [[TRportland_extras alloc] init];
        [TRStylet setPreflightObject:extras forIdent:self.ident];
    }
    
    TRCurves* curves = extras->curves;
    curves.inputImage = input;

    TRHueSat* sat = extras->sat;
    sat.inputImage = curves.outputImage;

    return sat.outputImage;
}
@end
