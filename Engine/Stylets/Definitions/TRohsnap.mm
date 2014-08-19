#import "TRStylet.h"

static int ddLogLevel = LOG_LEVEL_INFO;

using tr::util::Spline;

@interface TRohsnap_extras : NSObject {
@package
    TRCurves* contrast;
    TRHueSat* huesat1;
}
@end

@implementation TRohsnap_extras
- (id) init {
    TRUNUSED CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    
    Spline rgb1;
    rgb1.addKnot(Spline::Knot(0, 0) / 255.0);
    rgb1.addKnot(Spline::Knot(16, 4) / 255.0);
    rgb1.addKnot(Spline::Knot(51, 36) / 255.0);
    rgb1.addKnot(Spline::Knot(128, 128) / 255.0);
    rgb1.addKnot(Spline::Knot(199, 212) / 255.0);
    rgb1.addKnot(Spline::Knot(239, 248) / 255.0);
    rgb1.addKnot(Spline::Knot(255, 255) / 255.0);
    contrast = [TRCurves newWithInput:nil rgb:rgb1];

    HueSatAdjustments adj1;
    adj1.slices.push_back(
      HueSatAdjustments::Slice(0,0,0,0,         0,  0.1, 0));
    adj1.slices.push_back(
      HueSatAdjustments::Slice(315,345,15,49,   0, -0.1, 0));
    huesat1 = [TRHueSat newWithInput:nil hueSat:adj1];

    TRUNUSED CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    DDLogVerbose(@"TRohsnap_extras init took %0.3f seconds", end - start);
    
    return self;
}
- (id) copyWithZone:(NSZone*)zone {
    return self;
}
@end

@implementation TRohsnap
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.ohsnap"
      name:@"Oh, Snap!" group:@"Basic Adjustments" code:@"Sn"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1],
          [TRNumberKnob newKnobIdentifiedBy:@"snap" named:@"Snap"
            value:100 uiMin:0 uiMax:200 actualMin:0 actualMax:1.2],
          [TRNumberKnob newKnobIdentifiedBy:@"saturation1" named:@"Saturation"
            value:100 uiMin:0 uiMax:200 actualMin:0 actualMax:2],
          nil];
    }
    return self;
}
- (CIImage*) applyTo:(CIImage*)input {
    TRohsnap_extras* extras = [TRStylet preflightObjectForIdent:self.ident];
    if (!extras) {
        extras = [[TRohsnap_extras alloc] init];
        [TRStylet setPreflightObject:extras forIdent:self.ident];
    }

    TRBlur* highpassblur = [TRBlur newWithInput:input
      radius:[NSNumber numberWithFloat:0.001]];

    TRHighPass* highpass1 =
      [TRHighPass newWithInput:input blurredImage:highpassblur.outputImage];

    TRGreyMix* highpassdesat = [TRGreyMix newWithInput:highpass1.outputImage];

    TRBlend* snap =
      [TRBlend newWithInput:highpassdesat.outputImage background:input
      mode:SOFT_LIGHT strength:[self valueForKnob:@"snap"]];

    TRCurves* contrast = extras->contrast;
    contrast.inputImage = snap.outputImage;

    TRHueSat* huesat1 = extras->huesat1;
    huesat1.inputImage = contrast.outputImage;

    /*
    // XXX: This blend causes the iPhone to display a blank white result
    // We're not using the saturation1 knob anyway, so omit it.
    TRBlend* satblend = [TRBlend newWithInput:huesat1.outputImage
      background:contrast.outputImage mode:NORMAL
      strength:[self valueForKnob:@"saturation1"]];
    */

    return huesat1.outputImage;
}
@end
