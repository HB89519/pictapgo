#import "TRStylet.h"

static int ddLogLevel = LOG_LEVEL_INFO;

using tr::util::Spline;

@interface TRsfh_extras : NSObject {
@package
    TRCurves* warm_it_up;
}
@end

@implementation TRsfh_extras
- (id) init {
    TRUNUSED CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    
    Spline iota = Spline::ident();
    Spline r1, b1;
    r1.addKnot(Spline::Knot(0, 0) / 255.0);
    r1.addKnot(Spline::Knot(131, 146) / 255.0);
    r1.addKnot(Spline::Knot(255, 255) / 255.0);
    b1.addKnot(Spline::Knot(0, 0) / 255.0);
    b1.addKnot(Spline::Knot(131, 112) / 255.0);
    b1.addKnot(Spline::Knot(255, 255) / 255.0);
    warm_it_up = [TRCurves newWithInput:nil rgb:iota r:r1 g:iota b:b1];
    //[warm_it_up setStrength:[self valueForKnob:@"warm_it_up_strength"]];
    [warm_it_up setStrength:[NSNumber numberWithFloat:0.5]];
    
    TRUNUSED CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    DDLogVerbose(@"TRsfh_extras init took %0.3f seconds", end - start);
    
    return self;
}
- (id) copyWithZone:(NSZone*)zone {
    return self;
}
@end

@implementation TRsfh
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.sfh"
      name:@"Super Fun Happy" group:@"Modern Color" code:@"Sf"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"glow_amount" named:@"Glow"
            value:100 uiMin:0 uiMax:200 actualMin:0 actualMax:0.01],
          [TRNumberKnob newKnobIdentifiedBy:@"glow_strength" named:@"Boost"
            value:100 uiMin:0 uiMax:200 actualMin:0 actualMax:1.4],
          [TRNumberKnob newKnobIdentifiedBy:@"desaturation_strength"
            named:@"Desaturation + Tone Shift"
            value:100 uiMin:0 uiMax:200 actualMin:0 actualMax:0.8],
          [TRNumberKnob newKnobIdentifiedBy:@"warm_it_up_strength"
            named:@"Warmth"
            value:100 uiMin:0 uiMax:200 actualMin:0 actualMax:1.0],
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1.0],
          nil];
    }
    return self;
}
- (CIImage*) applyTo:(CIImage*)input {
    TRsfh_extras* extras = [TRStylet preflightObjectForIdent:self.ident];
    if (!extras) {
        extras = [[TRsfh_extras alloc] init];
        [TRStylet setPreflightObject:extras forIdent:self.ident];
    }

    //TRBlur* glow = [TRBlur newWithInput:input
    //  radius:[self valueForKnob:@"glow_amount"]];

    TRBlend* glow_blend = [TRBlend newWithInput:input background:input
      mode:OVERLAY strength:[self valueForKnob:@"glow_strength"]];
    TRGreyMix* desaturation = [TRGreyMix newWithInput:glow_blend.outputImage];
    TRBlend* desaturation_blend = [TRBlend newWithInput:desaturation.outputImage
      background:glow_blend.outputImage mode:NORMAL
      strength:[self valueForKnob:@"desaturation_strength"]];
    
    TRCurves* warm_it_up = extras->warm_it_up;
    warm_it_up.inputImage = desaturation_blend.outputImage;
    
    return warm_it_up.outputImage;
}
@end
