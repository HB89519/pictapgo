#import "TRStylet.h"

static int ddLogLevel = LOG_LEVEL_INFO;

using tr::util::Spline;

@interface TRbitchinbw_extras : NSObject {
@package
    TRCurves* contrast;
}
@end

@implementation TRbitchinbw_extras
- (id) init {
    TRUNUSED CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();

    Spline rgb1;
    rgb1.addKnot(Spline::Knot(0, 0) / 255.0);
    rgb1.addKnot(Spline::Knot(15, 5) / 255.0);
    rgb1.addKnot(Spline::Knot(56, 37) / 255.0);
    rgb1.addKnot(Spline::Knot(203, 213) / 255.0);
    rgb1.addKnot(Spline::Knot(240, 249) / 255.0);
    rgb1.addKnot(Spline::Knot(255, 255) / 255.0);
    contrast = [TRCurves newWithInput:nil rgb:rgb1];

    TRUNUSED CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    DDLogVerbose(@"TRbitchinbw_extras init took %0.3f seconds", end - start);
    
    return self;
}
- (id) copyWithZone:(NSZone*)zone {
    return self;
}
@end

@implementation TRbitchinbw
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.bitchinbw"
      name:@"Salt + Pepper" group:@"Black and White" code:@"Sp"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Effect Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1],
          [TRNumberKnob newKnobIdentifiedBy:@"intensity" named:@"Intensity"
            value:100 uiMin:0 uiMax:300 actualMin:0 actualMax:3],
          [TRNumberKnob newKnobIdentifiedBy:@"contrast" named:@"Contrast"
            value:100 uiMin:0 uiMax:200 actualMin:0 actualMax:2],
          nil];
    }
    return self;
}

- (CIImage*) applyTo:(CIImage*)input {
    TRbitchinbw_extras* extras = [TRStylet preflightObjectForIdent:self.ident];
    if (!extras) {
        extras = [[TRbitchinbw_extras alloc] init];
        [TRStylet setPreflightObject:extras forIdent:self.ident];
    }

    TRGreyMix* standardgrey = [TRGreyMix newWithInput:input];

    TRLabGrey* labgrey1 = [TRLabGrey newWithInput:input];

    TRCurves* contrast = [extras->contrast copy];
    contrast.inputImage = labgrey1.outputImage;
    [contrast setStrength:[self valueForKnob:@"contrast"]];

    TRBlend* intensity = [TRBlend newWithInput:contrast.outputImage
      background:standardgrey.outputImage mode:NORMAL
      strength:[self valueForKnob:@"intensity"]];

    return intensity.outputImage;
}
@end
