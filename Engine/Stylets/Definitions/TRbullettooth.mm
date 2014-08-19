#import "TRStylet.h"

static int ddLogLevel = LOG_LEVEL_INFO;

using tr::util::Spline;

@interface TRbullettooth_extras : NSObject {
@package
    TRLevels* brightness;
    TRCurves* curves1;
}
@end

@implementation TRbullettooth_extras
- (id) init {
    TRUNUSED CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();

    LevelsAdjustments adj1;
    adj1.adj[3].outMin = 0;
    adj1.adj[3].outMax = 255;
    brightness = [TRLevels newWithInput:nil levels:adj1];
    
    Spline rgb1;
    rgb1.addKnot(Spline::Knot(0, 0) / 255.0);
    rgb1.addKnot(Spline::Knot(242, 253) / 255.0);
    rgb1.addKnot(Spline::Knot(255, 255) / 255.0);
    curves1 = [TRCurves newWithInput:nil rgb:rgb1];
    
    TRUNUSED CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    DDLogVerbose(@"TRbullettooth_extras init took %0.3f seconds", end - start);
    
    return self;
}
- (id) copyWithZone:(NSZone*)zone {
    return self;
}
@end

@implementation TRbullettooth
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.bullettooth"
      name:@"Bullet Tooth" group:@"Modern Color" code:@"Bt"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1],
          [TRNumberKnob newKnobIdentifiedBy:@"brightnessamount" named:@"Brightness"
            value:100 uiMin:0 uiMax:100 actualMin:210 actualMax:255],
          [TRNumberKnob newKnobIdentifiedBy:@"gain" named:@"Gain"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1],
          nil];
    }
    return self;
}
- (CIImage*) applyTo:(CIImage*)input {
    TRbullettooth_extras* extras = [TRStylet preflightObjectForIdent:self.ident];
    if (!extras) {
        extras = [[TRbullettooth_extras alloc] init];
        [TRStylet setPreflightObject:extras forIdent:self.ident];
    }

    TRLevels* brightness = [extras->brightness copy];
    brightness.inputImage = input;

    TRChannelMix* chmix = [TRChannelMix newWithInput:brightness.outputImage
      r:[CIVector vectorWithX:0.5 Y:0.5 Z:0.0]
      g:[CIVector vectorWithX:0.0 Y:1.0 Z:0.0]
      b:[CIVector vectorWithX:0.0 Y:0.5 Z:0.5]];

    TRCurves* curves1 = [extras->curves1 copy];
    curves1.inputImage = chmix.outputImage;

    TRBlur* hpblur = [TRBlur newWithInput:curves1.outputImage
      radius:[NSNumber numberWithFloat:0.035]];

    TRHighPass* highpass1 =
      [TRHighPass newWithInput:curves1.outputImage blurredImage:hpblur.outputImage];

    TRBlend* hpblend = [TRBlend newWithInput:highpass1.outputImage
      background:curves1.outputImage mode:SOFT_LIGHT
      strength:[self valueForKnob:@"gain"]];

    return hpblend.outputImage;
}
@end
