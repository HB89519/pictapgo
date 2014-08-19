#import "TRStylet.h"

static int ddLogLevel = LOG_LEVEL_INFO;

using tr::util::Spline;

@interface TRclaireify_extras : NSObject {
@package
    TRCurves* tonecurve;
    TRCurves* contrastbump;
}
@end

@implementation TRclaireify_extras
- (id) init {
    TRUNUSED CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();

    Spline rgb1;
    rgb1.addKnot(Spline::Knot(3, 0) / 255.0);
    rgb1.addKnot(Spline::Knot(20, 23) / 255.0);
    rgb1.addKnot(Spline::Knot(87, 108) / 255.0);
    rgb1.addKnot(Spline::Knot(187, 203) / 255.0);
    rgb1.addKnot(Spline::Knot(255, 255) / 255.0);
    tonecurve = [TRCurves newWithInput:nil rgb:rgb1];

    Spline rgb2;
    rgb2.addKnot(Spline::Knot(0, 0) / 255.0);
    rgb2.addKnot(Spline::Knot(31, 25) / 255.0);
    rgb2.addKnot(Spline::Knot(57, 61) / 255.0);
    rgb2.addKnot(Spline::Knot(255, 255) / 255.0);
    contrastbump = [TRCurves newWithInput:nil rgb:rgb2];

    TRUNUSED CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    DDLogVerbose(@"TRclaireify_extras init took %0.3f seconds", end - start);
    
    return self;
}
- (id) copyWithZone:(NSZone*)zone {
    return self;
}
@end

@implementation TRclaireify
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.claireify"
      name:@"Brightside" group:@"Basic Adjustments" code:@"Br"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1.0],
          nil];
    }
    return self;
}
- (CIImage*) applyTo:(CIImage*)input {
    TRclaireify_extras* extras = [TRStylet preflightObjectForIdent:self.ident];
    if (!extras) {
        extras = [[TRclaireify_extras alloc] init];
        [TRStylet setPreflightObject:extras forIdent:self.ident];
    }

    TRCurves* tonecurve = [extras->tonecurve copy];
    tonecurve.inputImage = input;

    TRCurves* contrastbump = [extras->contrastbump copy];
    contrastbump.inputImage = tonecurve.outputImage;

    return contrastbump.outputImage;
}
@end

