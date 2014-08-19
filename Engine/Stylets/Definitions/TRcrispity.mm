#import "TRStylet.h"

static int ddLogLevel = LOG_LEVEL_INFO;

using tr::util::Spline;

@interface TRcrispity_extras : NSObject {
    @package
    TRCurves* curve;
}
@end

@implementation TRcrispity_extras
- (id) init {
    TRUNUSED CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    Spline c1;
    c1.addKnot(Spline::Knot(0, 255) / 255.0);
    c1.addKnot(Spline::Knot(128, 128) / 255.0);
    c1.addKnot(Spline::Knot(255, 224) / 255.0);
    curve = [TRCurves newWithInput:nil rgb:c1];
    TRUNUSED CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    DDLogVerbose(@"TRcrispity_extras init took %0.3f seconds", end - start);

    return self;
}
- (id) copyWithZone:(NSZone*)zone {
    return self;
}
@end

@implementation TRcrispity
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.crispity"
      name:@"Crispity" group:@"Sharpening" code:@"Cr"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1.0],
          nil];
    }
    return self;
}
- (CIImage*) applyTo:(CIImage*)input {
    TRcrispity_extras* extras = [TRStylet preflightObjectForIdent:self.ident];
    if (!extras) {
        extras = [[TRcrispity_extras alloc] init];
        [TRStylet setPreflightObject:extras forIdent:self.ident];
    }
    TRGreyMix* desat = [TRGreyMix newWithInput:input];

    TRCurves* curves = [extras->curve copy];
    curves.inputImage = desat.outputImage;

    TRBlur* hpblur = [TRBlur newWithInput:input radius:[NSNumber numberWithFloat:0.025]];
    TRHighPass* hp = [TRHighPass newWithInput:input blurredImage:hpblur.outputImage];

    TRBlend* blend = [TRBlend newWithInput:hp.outputImage background:input
      mode:HARD_LIGHT];
    TRBlend* mblend = [TRBlend newWithInput:blend.outputImage background:input
      mask:curves.outputImage];

    return mblend.outputImage;
}
@end
