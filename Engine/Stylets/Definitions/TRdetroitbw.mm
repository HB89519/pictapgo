#import "TRStylet.h"

static int ddLogLevel = LOG_LEVEL_INFO;

using tr::util::Spline;

@interface TRdetroitbw_extras : NSObject {
@package
    TRCurves* contrast;
    TRCurves* compression;
    TRLevels* toning;
}
@end

@implementation TRdetroitbw_extras
- (id) init {
    TRUNUSED CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();

    Spline rgb1;
    rgb1.addKnot(Spline::Knot(0, 0) / 255.0);
    rgb1.addKnot(Spline::Knot(35, 26) / 255.0);
    rgb1.addKnot(Spline::Knot(102, 110) / 255.0);
    rgb1.addKnot(Spline::Knot(186, 214) / 255.0);
    rgb1.addKnot(Spline::Knot(255, 255) / 255.0);
    contrast = [TRCurves newWithInput:nil rgb:rgb1];

    Spline rgb2;
    rgb2.addKnot(Spline::Knot(0, 17) / 255.0);
    rgb2.addKnot(Spline::Knot(255, 185) / 255.0);
    compression = [TRCurves newWithInput:nil rgb:rgb2];

    LevelsAdjustments adj1;
    adj1.adj[0].outMin = 0;
    adj1.adj[0].outMax = 245;
    adj1.adj[1].outMin = 0;
    adj1.adj[1].outMax = 250;
    adj1.adj[1].gamma = 0.97;
    adj1.adj[2].outMin = 4;
    adj1.adj[2].outMax = 255;
    adj1.adj[2].gamma = 1.05;
    toning = [TRLevels newWithInput:nil levels:adj1];

    TRUNUSED CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    DDLogVerbose(@"TRdetroitbw_extras init took %0.3f seconds", end - start);

    return self;
}
- (id) copyWithZone:(NSZone*)zone {
    return self;
}
@end

@implementation TRdetroitbw
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.detroitbw"
      name:@"Detroit" group:@"Black and White" code:@"Dt"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1],
          [TRNumberKnob newKnobIdentifiedBy:@"snap" named:@"Snap"
            value:100 uiMin:0 uiMax:200 actualMin:0 actualMax:2],
          [TRNumberKnob newKnobIdentifiedBy:@"intensity" named:@"Intensity"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1],
          [TRNumberKnob newKnobIdentifiedBy:@"toningamount" named:@"Toning"
            value:100 uiMin:0 uiMax:200 actualMin:0 actualMax:2],
          [TRNumberKnob newKnobIdentifiedBy:@"contrastamount" named:@"Midtone Contrast"
            value:100 uiMin:0 uiMax:200 actualMin:0 actualMax:2],
          [TRNumberKnob newKnobIdentifiedBy:@"compressionamount" named:@"Tone Compression"
            value:100 uiMin:0 uiMax:200 actualMin:0 actualMax:2],
          nil];
    }
    return self;
}
- (CIImage*) applyTo:(CIImage*)input {
    TRdetroitbw_extras* extras = [TRStylet preflightObjectForIdent:self.ident];
    if (!extras) {
        extras = [[TRdetroitbw_extras alloc] init];
        [TRStylet setPreflightObject:extras forIdent:self.ident];
    }

    TRGreyMix* desat = [TRGreyMix newWithInput:input];

    TRCurves* contrast = [extras->contrast copy];
    contrast.inputImage = desat.outputImage;
    [contrast setStrength:[self valueForKnob:@"contrastamount"]];
    desat = nil;

    TRCurves* compression1 = [extras->compression copy];
    compression1.inputImage = contrast.outputImage;
    [compression1 setStrength:[self valueForKnob:@"compressionamount"]];
    contrast = nil;

    TRRollup* compression = [TRRollup newWithInput:compression1.outputImage];
    compression1 = nil;

    TRBlur* blur1 = [TRBlur newWithInput:compression.outputImage
      radius:[NSNumber numberWithFloat:0.01]];

    TRHighPass* highpass1 = [TRHighPass newWithInput:compression.outputImage
      blurredImage:blur1.outputImage];
    blur1 = nil;

    TRBlend* highpassblend = [TRBlend newWithInput:highpass1.outputImage
      background:compression.outputImage mode:SOFT_LIGHT
      strength:[self valueForKnob:@"snap"]];
    compression = nil;
    highpass1 = nil;

    TRRollup* rollup = [TRRollup newWithInput:highpassblend.outputImage];
    highpassblend = nil;

    TRLevels* toning = [extras->toning copy];
    toning.inputImage = rollup.outputImage;
    [toning setStrength:[self valueForKnob:@"toningamount"]];
    rollup = nil;

    return toning.outputImage;
}
@end
