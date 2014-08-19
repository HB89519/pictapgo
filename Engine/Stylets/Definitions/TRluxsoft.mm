#import "TRStylet.h"

using tr::util::Spline;

@implementation TRluxsoft
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.luxsoft"
      name:@"Lux" group:@"Modern Color" code:@"Lx"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1],
          [TRNumberKnob newKnobIdentifiedBy:@"snap" named:@"Snap"
            value:100 uiMin:0 uiMax:200 actualMin:0 actualMax:1.2],
          nil];
    }
    return self;
}
- (CIImage*) applyTo:(CIImage*)input {
    TRBlur* blur1 = [TRBlur newWithInput:input radius:[NSNumber numberWithFloat:0.021]];

    TRHighPass* highpass1 = [TRHighPass newWithInput:input blurredImage:blur1.outputImage];
    
    TRGreyMix* highpassdesat = [TRGreyMix newWithInput:highpass1.outputImage
      r:[NSNumber numberWithFloat:0.33] g:[NSNumber numberWithFloat:0.34]
      b:[NSNumber numberWithFloat:0.33]];
    
    Spline rgb;
    rgb.addKnot(Spline::Knot(0, 61) / 255.0);
    rgb.addKnot(Spline::Knot(96,99) / 255.0);
    rgb.addKnot(Spline::Knot(128,128) / 255.0);
    rgb.addKnot(Spline::Knot(159,128) / 255.0);
    rgb.addKnot(Spline::Knot(203,128) / 255.0);
    rgb.addKnot(Spline::Knot(255,128) / 255.0);
    TRCurves* highpasscurve = [TRCurves newWithInput:highpassdesat.outputImage rgb:rgb];
    
    TRBlend* highpassblend = [TRBlend newWithInput:highpasscurve.outputImage
      background:input mode:SOFT_LIGHT strength:[self valueForKnob:@"snap"]];
    
    LevelsAdjustments adj;
    adj.adj[3].outMin = 15;
    adj.adj[3].outMax = 248;
    adj.adj[0].inMin = 0;
    adj.adj[0].inMax = 253;
    adj.adj[0].outMin = 0;
    adj.adj[0].outMax = 252;
    adj.adj[1].outMin = 0;
    adj.adj[1].outMax = 253;
    adj.adj[2].outMin = 4;
    adj.adj[2].outMax = 211;
    adj.adj[2].gamma = 1.19;
    TRLevels* colortweak = [TRLevels newWithInput:highpassblend.outputImage levels:adj];
    
    Spline rgb2;
    rgb2.addKnot(Spline::Knot(0,0) / 255.0);
    rgb2.addKnot(Spline::Knot(16,16) / 255.0);
    rgb2.addKnot(Spline::Knot(41,46) / 255.0);
    rgb2.addKnot(Spline::Knot(255,255) / 255.0);
    TRCurves* midtonelift = [TRCurves newWithInput:colortweak.outputImage rgb:rgb2];
    
    return midtonelift.outputImage;
}
@end
