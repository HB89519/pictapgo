#import "TRStylet.h"

static int ddLogLevel = LOG_LEVEL_INFO;

using tr::util::Spline;

@interface TRmontecito_extras : NSObject {
@package
    TRCurves* flarecurve;
    TRCurves* flarewarming;
    TRCurves* curves1;
    TRHueSat* huesat1;
    TRLevels* levels1;
    TRCurves* curves2;
}
@end

@implementation TRmontecito_extras
- (id) init {
    TRUNUSED CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();

    Spline iota = Spline::ident();
    
    Spline rgb1;
    rgb1.addKnot(Spline::Knot(128, 128) / 255.0);
    rgb1.addKnot(Spline::Knot(255, 255) / 255.0);
    flarecurve = [TRCurves newWithInput:nil rgb:rgb1];
    
    Spline r1, b1;
    r1.addKnot(Spline::Knot(0, 0) / 255.0);
    r1.addKnot(Spline::Knot(131, 146) / 255.0);
    r1.addKnot(Spline::Knot(255, 255) / 255.0);

    b1.addKnot(Spline::Knot(0, 0) / 255.0);
    b1.addKnot(Spline::Knot(131, 112) / 255.0);
    b1.addKnot(Spline::Knot(255, 255) / 255.0);

    flarewarming = [TRCurves newWithInput:nil rgb:iota r:r1 g:iota b:b1];
    [flarewarming setStrength:[NSNumber numberWithFloat:0]];
    
    Spline rgb2, r2, g2, b2;
    rgb2.addKnot(Spline::Knot(0, 0) / 255.0);
    rgb2.addKnot(Spline::Knot(8, 3) / 255.0);
    rgb2.addKnot(Spline::Knot(31, 32) / 255.0);
    rgb2.addKnot(Spline::Knot(95, 119) / 255.0);
    rgb2.addKnot(Spline::Knot(233, 245) / 255.0);
    rgb2.addKnot(Spline::Knot(255, 255) / 255.0);

    r2.addKnot(Spline::Knot(0, 0) / 255.0);
    r2.addKnot(Spline::Knot(117, 125) / 255.0);
    r2.addKnot(Spline::Knot(153, 163) / 255.0);
    r2.addKnot(Spline::Knot(255, 255) / 255.0);

    g2.addKnot(Spline::Knot(0, 0) / 255.0);
    g2.addKnot(Spline::Knot(196, 201) / 255.0);
    g2.addKnot(Spline::Knot(255, 255) / 255.0);

    b2.addKnot(Spline::Knot(0, 0) / 255.0);
    b2.addKnot(Spline::Knot(12, 11) / 255.0);
    b2.addKnot(Spline::Knot(197, 195) / 255.0);
    b2.addKnot(Spline::Knot(255, 233) / 255.0);
    curves1 = [TRCurves newWithInput:nil rgb:rgb2 r:r2 g:g2 b:b2];

    HueSatAdjustments adj1;
    adj1.slices.push_back(
      HueSatAdjustments::Slice(0,0,0,0,         0, -0.08, 0));
    adj1.slices.push_back(
      HueSatAdjustments::Slice(315,345,15,45,   0, -0.07, 0));
    adj1.slices.push_back(
      HueSatAdjustments::Slice(33,63,93,123,   19, -0.51, 0));
    adj1.slices.push_back(
      HueSatAdjustments::Slice(135,165,195,225, 0,  0.05, 0));
    adj1.slices.push_back(
      HueSatAdjustments::Slice(331,1,31,61,     0,  0.03, 0));
    huesat1 = [TRHueSat newWithInput:nil hueSat:adj1];

    LevelsAdjustments adj2;
    adj2.adj[3].outMin = 7;
    adj2.adj[3].outMax = 238;
    adj2.adj[3].gamma = 1.06;
    levels1 = [TRLevels newWithInput:nil levels:adj2];

    Spline rgb3, b3;
    rgb3.addKnot(Spline::Knot(0, 0) / 255.0);
    rgb3.addKnot(Spline::Knot(10, 9) / 255.0);
    rgb3.addKnot(Spline::Knot(84, 94) / 255.0);
    rgb3.addKnot(Spline::Knot(212, 218) / 255.0);
    rgb3.addKnot(Spline::Knot(243, 244) / 255.0);
    rgb3.addKnot(Spline::Knot(255, 255) / 255.0);

    b3.addKnot(Spline::Knot(0, 0) / 255.0);
    b3.addKnot(Spline::Knot(47, 43) / 255.0);
    b3.addKnot(Spline::Knot(127, 126) / 255.0);
    b3.addKnot(Spline::Knot(255, 255) / 255.0);
    curves2 = [TRCurves newWithInput:nil rgb:rgb3 r:iota g:iota b:b3];
    
    TRUNUSED CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    DDLogVerbose(@"TRmontecito_extras init took %0.3f seconds", end - start);
    
    return self;
}
- (id) copyWithZone:(NSZone*)zone {
    return self;
}
@end

@implementation TRmontecito
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.montecito"
      name:@"Montecito" group:@"Vintage Color" code:@"Mc"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"brightnessamount" named:@"Brightness"
            value:0 uiMin:-200 uiMax:200 actualMin:-2 actualMax:2],
          [TRNumberKnob newKnobIdentifiedBy:@"flareamount" named:@"Flare Amount"
            value:100 uiMin:0 uiMax:300 actualMin:0 actualMax:3],
          [TRNumberKnob newKnobIdentifiedBy:@"flarewarmamount" named:@"Flare Warmth"
            value:0 uiMin:-200 uiMax:200 actualMin:-2 actualMax:2],
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1],
          nil];
    }
    return self;
}
- (CIImage*) applyTo:(CIImage*)input {
    TRmontecito_extras* extras = [TRStylet preflightObjectForIdent:self.ident];
    if (!extras) {
        extras = [[TRmontecito_extras alloc] init];
        [TRStylet setPreflightObject:extras forIdent:self.ident];
    }

    TRBlend* brightness1 = [TRBlend newWithInput:input background:input
      mode:SCREEN strength:[self valueForKnob:@"brightnessamount"]];

    TRGreyMix* flaredesat = [TRGreyMix newWithInput:brightness1.outputImage];

    TRCurves* flarecurve = [extras->flarecurve copy];
    flarecurve.inputImage = flaredesat.outputImage;

    TRBlur* flareblur = [TRBlur newWithInput:flarecurve.outputImage
      radius:[NSNumber numberWithFloat:0.025]];

    TRCurves* flarewarming = [extras->flarewarming copy];
    flarewarming.inputImage = flareblur.outputImage;
    /*
    [flarewarming
      setStrength:[self valueForKnob:@"flarewarmamount"]];
    */
    
    TRBlend* flare = [TRBlend newWithInput:flarewarming.outputImage
      background:brightness1.outputImage mode:SOFT_LIGHT
      strength:[self valueForKnob:@"flareamount"]];

    TRCurves* curves1 = [extras->curves1 copy];
    curves1.inputImage = flare.outputImage;
    
    TRHueSat* huesat1 = [extras->huesat1 copy];
    huesat1.inputImage = curves1.outputImage;

    TRLevels* levels1 = [extras->levels1 copy];
    levels1.inputImage = huesat1.outputImage;

    TRCurves* curves2 = [extras->curves2 copy];
    curves2.inputImage = levels1.outputImage;

    return curves2.outputImage;
}
@end
