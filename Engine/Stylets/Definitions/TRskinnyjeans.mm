#import "TRStylet.h"

static int ddLogLevel = LOG_LEVEL_INFO;

using tr::util::Spline;

@interface TRskinnyjeans_extras : NSObject {
@package
    TRCurves* contrastcurve;
    TRCurves* highlightcurve;
    TRCurves* shadowcurve;
}
@end

@implementation TRskinnyjeans_extras
- (id) init {
    TRUNUSED CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    Spline c1, c2, c3;
    c1.addKnot(Spline::Knot(0, 0) / 255.0);
    c1.addKnot(Spline::Knot(64, 32) / 255.0);
    c1.addKnot(Spline::Knot(192, 224) / 255.0);
    c1.addKnot(Spline::Knot(255, 255) / 255.0);
    
    c2.addKnot(Spline::Knot(0, 0) / 255.0);
    c2.addKnot(Spline::Knot(128, 128) / 255.0);
    c2.addKnot(Spline::Knot(255, 205) / 255.0);

    c3.addKnot(Spline::Knot(0, 50) / 255.0);
    c3.addKnot(Spline::Knot(128, 128) / 255.0);
    c3.addKnot(Spline::Knot(255, 255) / 255.0);
    
    contrastcurve = [TRCurves newWithInput:nil rgb:c1];
    [contrastcurve setStrength:@1.0];
    highlightcurve = [TRCurves newWithInput:nil rgb:c2];
    [highlightcurve setStrength:@0.45];
    shadowcurve = [TRCurves newWithInput:nil rgb:c3];
    [shadowcurve setStrength:@0.85];

    TRUNUSED CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    DDLogVerbose(@"TRskinnyjeans_extras init took %0.3f seconds", end - start);

    return self;
}
- (id) copyWithZone:(NSZone*)zone {
    return self;
}
@end

@implementation TRskinnyjeans
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.skinnyjeans"
      name:@"Skinny Jeans" group:@"Vintage Color" code:@"Sj"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Contrast"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1],
          [TRNumberKnob newKnobIdentifiedBy:@"highlights" named:@"Highlights"
            value:100 uiMin:0 uiMax:200 actualMin:0 actualMax:0.9],
          [TRNumberKnob newKnobIdentifiedBy:@"shadows" named:@"Shadows"
            value:100 uiMin:0 uiMax:200 actualMin:0 actualMax:1.7],
          nil];
    }
    return self;
}
- (CIImage*) applyTo:(CIImage*)input {
    TRskinnyjeans_extras* extras = [TRStylet preflightObjectForIdent:self.ident];
    if (!extras) {
        extras = [[TRskinnyjeans_extras alloc] init];
        [TRStylet setPreflightObject:extras forIdent:self.ident];
    }

    TRCurves* contrastcurve = [extras->contrastcurve copy];
    contrastcurve.inputImage = input;

    TRCurves* highlightcurve = [extras->highlightcurve copy];
    highlightcurve.inputImage = contrastcurve.outputImage;

    TRCurves* shadowcurve = [extras->shadowcurve copy];
    shadowcurve.inputImage = highlightcurve.outputImage;

    return shadowcurve.outputImage;
}
@end
