#import "TRStylet.h"

static int ddLogLevel = LOG_LEVEL_INFO;

using tr::util::Spline;

@interface TRbrooklynbw_extras : NSObject {
@package
    TRCurves* contrast;
    TRCurves* hlselect;
}
@end

@implementation TRbrooklynbw_extras
- (id) init {
    TRUNUSED CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();

    Spline rgb1;
    rgb1.addKnot(Spline::Knot(0, 0) / 255.0);
    rgb1.addKnot(Spline::Knot(45, 37) / 255.0);
    rgb1.addKnot(Spline::Knot(126, 128) / 255.0);
    rgb1.addKnot(Spline::Knot(191, 202) / 255.0);
    rgb1.addKnot(Spline::Knot(231, 233) / 255.0);
    rgb1.addKnot(Spline::Knot(255, 255) / 255.0);
    contrast = [TRCurves newWithInput:nil rgb:rgb1];

    Spline rgb2;
    rgb2.addKnot(Spline::Knot(114, 0) / 255.0);
    rgb2.addKnot(Spline::Knot(124, 6) / 255.0);
    rgb2.addKnot(Spline::Knot(144, 48) / 255.0);
    rgb2.addKnot(Spline::Knot(209, 219) / 255.0);
    rgb2.addKnot(Spline::Knot(246, 255) / 255.0);
    hlselect = [TRCurves newWithInput:nil rgb:rgb2];

    TRUNUSED CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    DDLogVerbose(@"TRbrooklynbw_extras init took %0.3f seconds", end - start);

    return self;
}
- (id) copyWithZone:(NSZone*)zone {
    return self;
}
@end

@implementation TRbrooklynbw
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.brooklynbw"
      name:@"Brooklyn" group:@"Black and White" code:@"Bk"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Effect Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1],
          [TRNumberKnob newKnobIdentifiedBy:@"intensity" named:@"Intensity"
            value:100 uiMin:0 uiMax:200 actualMin:0 actualMax:2],
          [TRNumberKnob newKnobIdentifiedBy:@"contrastamount" named:@"Contrast"
            value:100 uiMin:0 uiMax:200 actualMin:0 actualMax:2],
          [TRNumberKnob newKnobIdentifiedBy:@"snap" named:@"Snap"
            value:100 uiMin:0 uiMax:200 actualMin:0 actualMax:2],
          [TRNumberKnob newKnobIdentifiedBy:@"hlrecoveryamount"
            named:@"Highlight Preservation"
            value:100 uiMin:0 uiMax:200 actualMin:0 actualMax:2],
          nil];
    }
    return self;
}

- (CIImage*) applyTo:(CIImage*)input {
    TRbrooklynbw_extras* extras = [TRStylet preflightObjectForIdent:self.ident];
    if (!extras) {
        extras = [[TRbrooklynbw_extras alloc] init];
        [TRStylet setPreflightObject:extras forIdent:self.ident];
    }

    TRGreyMix* greymix1 = [TRGreyMix newWithInput:input r:@0.23 g:@0.23 b:@0.54];

    TRCurves* contrast1 = [extras->contrast copy];
    contrast1.inputImage = greymix1.outputImage;
    [contrast1 setStrength:[self valueForKnob:@"contrastamount"]];
    greymix1 = nil;

    TRRollup* contrast = [TRRollup newWithInput:contrast1.outputImage];
    contrast1 = nil;

    TRBlur* hpblur = [TRBlur newWithInput:contrast.outputImage radius:@0.03];
    TRHighPass* highpass1 = [TRHighPass newWithInput:contrast.outputImage
      blurredImage:hpblur.outputImage];
    hpblur = nil;

    TRBlend* hpblend1 = [TRBlend newWithInput:highpass1.outputImage
      background:contrast.outputImage mode:OVERLAY];
    highpass1 = nil;
    TRRollup* hpblend = [TRRollup newWithInput:hpblend1.outputImage];
    hpblend1 = nil;

    TRGreyMix* hldesat = [TRGreyMix newWithInput:contrast.outputImage];

    TRCurves* hlselect = [extras->hlselect copy];
    hlselect.inputImage = hldesat.outputImage;
    hldesat = nil;

    TRBlur* hlmask = [TRBlur newWithInput:hlselect.outputImage radius:@0.001];
    hlselect = nil;

    TRUnsharpMask* usm1 = [TRUnsharpMask newWithInput:contrast.outputImage
      radius:@0.0013 amount:@0.90];
    contrast = nil;
    TRBlend* hlrecoveryd = [TRBlend newWithInput:usm1.outputImage
      background:hpblend.outputImage mode:DARKEN];
    usm1 = nil;
    TRBlend* hlrecovery = [TRBlend newWithInput:hlrecoveryd.outputImage
      background:hpblend.outputImage mask:hlmask.outputImage];
    hlrecoveryd = nil;
    hpblend = nil;
    hlmask = nil;

    // omit "intensity" blend and "effect strength" blend

    return hlrecovery.outputImage;
}
@end
