#import "TRStylet.h"

static int ddLogLevel = LOG_LEVEL_INFO;

using tr::util::Spline;

@interface TRgrandma_extras : NSObject {
@package
    TRCurves* curves1;
    TRLevels* toning;
}
@end

@implementation TRgrandma_extras
- (id) init {
    TRUNUSED CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    Spline rgb1;
    rgb1.addKnot(Spline::Knot(0, 0) / 255.0);
    rgb1.addKnot(Spline::Knot(22, 30) / 255.0);
    rgb1.addKnot(Spline::Knot(117, 135) / 255.0);
    rgb1.addKnot(Spline::Knot(196, 198) / 255.0);
    rgb1.addKnot(Spline::Knot(255, 255) / 255.0);
    curves1 = [TRCurves newWithInput:nil rgb:rgb1];

    LevelsAdjustments adj1;
    adj1.adj[3].outMin = 18;
    adj1.adj[3].outMax = 247;
    adj1.adj[0].outMin = 38;
    adj1.adj[0].outMax = 255;
    adj1.adj[1].outMin = 0;
    adj1.adj[1].outMax = 229;
    adj1.adj[2].outMin = 0;
    adj1.adj[2].outMax = 165;
    toning = [TRLevels newWithInput:nil levels:adj1];

    TRUNUSED CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    DDLogVerbose(@"TRgrandma_extras init took %0.3f seconds", end - start);
    
    return self;
}
- (id) copyWithZone:(NSZone*)zone {
    return self;
}
@end

@implementation TRgrandma
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.grandma"
      name:@"Mama's Tap Shoes" group:@"Vintage Color" code:@"Mm"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1],
          nil];
    }
    return self;
}
- (CIImage*) applyTo:(CIImage*)input {
    TRgrandma_extras* extras = [TRStylet preflightObjectForIdent:self.ident];
    if (!extras) {
        extras = [[TRgrandma_extras alloc] init];
        [TRStylet setPreflightObject:extras forIdent:self.ident];
    }

    TRCurves* curves1 = [extras->curves1 copy];
    curves1.inputImage = input;

    TRBlur* hpblur = [TRBlur newWithInput:curves1.outputImage
      radius:[NSNumber numberWithFloat:0.02]];

    TRHighPass* highpass1 = [TRHighPass newWithInput:curves1.outputImage blurredImage:hpblur.outputImage];
    hpblur = nil;

    TRGreyMix* hpdesat = [TRGreyMix newWithInput:highpass1.outputImage];
    highpass1 = nil;

    TRBlend* hpblend_0 = [TRBlend newWithInput:hpdesat.outputImage
      background:curves1.outputImage mode:OVERLAY];
    hpdesat = nil;
    curves1 = nil;

    TRRollup* hpblend = [TRRollup newWithInput:hpblend_0.outputImage];
    hpblend_0 = nil;

    TRGreyMix* maindesat = [TRGreyMix newWithInput:hpblend.outputImage
      r:[NSNumber numberWithFloat:0.33] g:[NSNumber numberWithFloat:0.33]
      b:[NSNumber numberWithFloat:0.34]];

    TRBlend* desatblend = [TRBlend newWithInput:maindesat.outputImage
      background:hpblend.outputImage mode:NORMAL strength:[NSNumber numberWithFloat:0.5]];
    hpblend = nil;
    maindesat = nil;

    TRLevels* toning = [extras->toning copy];
    toning.inputImage = desatblend.outputImage;
    desatblend = nil;

    return toning.outputImage;
}
@end
