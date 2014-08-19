#import "TRStylet.h"

static int ddLogLevel = LOG_LEVEL_INFO;

using tr::util::Spline;

@interface TRtroy_extras : NSObject {
@package
    TRHueSat* huesat1;
    TRCurves* curves1;
    TRCurves* curves2;
    TRHueSat* huesat2;
    TRLevels* toning;
}
@end

@implementation TRtroy_extras
- (id) init {
    TRUNUSED CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    
    HueSatAdjustments adj1;
    adj1.slices.push_back(
      HueSatAdjustments::Slice(0,0,0,0,         0, -0.4, 0));
    adj1.slices.push_back(
      HueSatAdjustments::Slice(315,345,15,45,   0, 0.10, 0));
    huesat1 = [TRHueSat newWithInput:nil hueSat:adj1];

    Spline rgb1;
    rgb1.addKnot(Spline::Knot(0, 0) / 255.0);
    rgb1.addKnot(Spline::Knot(40, 41) / 255.0);
    rgb1.addKnot(Spline::Knot(179, 195) / 255.0);
    rgb1.addKnot(Spline::Knot(255, 255) / 255.0);
    curves1 = [TRCurves newWithInput:nil rgb:rgb1];

    Spline rgb2, r2, g2, b2;
    rgb2.addKnot(Spline::Knot(0, 0) / 255.0);
    rgb2.addKnot(Spline::Knot(52, 58) / 255.0);
    rgb2.addKnot(Spline::Knot(222, 240) / 255.0);
    rgb2.addKnot(Spline::Knot(255, 248) / 255.0);
    r2.addKnot(Spline::Knot(0, 0) / 255.0);
    r2.addKnot(Spline::Knot(30, 29) / 255.0);
    r2.addKnot(Spline::Knot(79, 92) / 255.0);
    r2.addKnot(Spline::Knot(140, 156) / 255.0);
    r2.addKnot(Spline::Knot(255, 255) / 255.0);
    g2.addKnot(Spline::Knot(0, 0) / 255.0);
    g2.addKnot(Spline::Knot(76, 86) / 255.0);
    g2.addKnot(Spline::Knot(123, 130) / 255.0);
    g2.addKnot(Spline::Knot(255, 255) / 255.0);
    b2.addKnot(Spline::Knot(0, 0) / 255.0);
    b2.addKnot(Spline::Knot(45, 55) / 255.0);
    b2.addKnot(Spline::Knot(110, 101) / 255.0);
    b2.addKnot(Spline::Knot(208, 194) / 255.0);
    b2.addKnot(Spline::Knot(255, 236) / 255.0);
    curves2 = [TRCurves newWithInput:nil rgb:rgb2 r:r2 g:g2 b:b2];

    HueSatAdjustments adj2;
    adj2.slices.push_back(
      HueSatAdjustments::Slice(315,345,15,45,   0, 0.07, 0));
    adj2.slices.push_back(
      HueSatAdjustments::Slice(15,45,75,105,    0, -0.82, 0));
    adj2.slices.push_back(
      HueSatAdjustments::Slice(75,105,135,165,  0, -1.0, 0));
    adj2.slices.push_back(
      HueSatAdjustments::Slice(135,165,195,225, 0, -0.67, 0));
    adj2.slices.push_back(
      HueSatAdjustments::Slice(195,225,255,285, 0, -0.66, 0));
    huesat2 = [TRHueSat newWithInput:nil hueSat:adj2];
    
    LevelsAdjustments adj3;
    adj3.adj[1].outMin = 0;
    adj3.adj[1].outMax = 237;
    adj3.adj[2].outMin = 0;
    adj3.adj[2].outMax = 206;
    toning = [TRLevels newWithInput:nil levels:adj3];
    
    TRUNUSED CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    DDLogVerbose(@"TRtroy_extras init took %0.3f seconds", end - start);
    
    return self;
}
- (id) copyWithZone:(NSZone*)zone {
    return self;
}
@end

@implementation TRtroy
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.troy"
      name:@"Troy" group:@"Modern Color" code:@"Tr"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1],
          [TRNumberKnob newKnobIdentifiedBy:@"snap" named:@"Snap"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:0.65],
          [TRNumberKnob newKnobIdentifiedBy:@"effectamount" named:@"Effect"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1],
          [TRNumberKnob newKnobIdentifiedBy:@"toningamount" named:@"Warmth"
            value:100 uiMin:0 uiMax:200 actualMin:0 actualMax:2],
          nil];
    }
    return self;
}
- (CIImage*) applyTo:(CIImage*)input {
    TRtroy_extras* extras = [TRStylet preflightObjectForIdent:self.ident];
    if (!extras) {
        extras = [[TRtroy_extras alloc] init];
        [TRStylet setPreflightObject:extras forIdent:self.ident];
    }

    CIImage* result = nil;

    @autoreleasepool {
        TRLevels* toning = nil;
        @autoreleasepool {
            TRBlend* effectblend1 = nil;
            @autoreleasepool {
                TRHueSat* huesat1 = extras->huesat1;
                huesat1.inputImage = input;

                TRCurves* curves1 = extras->curves1;
                curves1.inputImage = huesat1.outputImage;
                huesat1 = nil;

                TRCurves* curves2 = extras->curves2;
                curves2.inputImage = curves1.outputImage;
                curves1 = nil;

                TRHueSat* huesat2 = extras->huesat2;
                huesat2.inputImage = curves2.outputImage;
                curves2 = nil;

                effectblend1 =
                  [TRBlend newWithInput:huesat2.outputImage background:input mode:NORMAL
                  strength:[self valueForKnob:@"effectamount"]];
                huesat2 = nil;
            }

            TRRollup* effectblend = [TRRollup newWithInput:effectblend1.outputImage];
            effectblend1 = nil;

            toning = extras->toning;
            toning.inputImage = effectblend.outputImage;
        }

        TRGreyMix* hpdesat = nil;
        @autoreleasepool {
            TRBlur* hpblur = [TRBlur newWithInput:toning.outputImage
              radius:[NSNumber numberWithFloat:0.01]];

            TRHighPass* highpass1 =
              [TRHighPass newWithInput:toning.outputImage blurredImage:hpblur.outputImage];
            hpblur = nil;

            hpdesat = [TRGreyMix newWithInput:highpass1.outputImage];
        }

        TRBlend* hpblend = [TRBlend newWithInput:hpdesat.outputImage
          background:toning.outputImage mode:SOFT_LIGHT
          strength:[self valueForKnob:@"snap"]];
        result = hpblend.outputImage;
    }

    return result;
}
@end
