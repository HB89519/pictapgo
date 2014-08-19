#import "TRStylet.h"

static int ddLogLevel = LOG_LEVEL_INFO;
using tr::util::Spline;

@interface TRinstagram_extras : NSObject {
@package
    TRCurves* contrastcurve;
    TRCurves* highlightcurve;
    TRCurves* shadowcurve;
}
@end

@implementation TRinstagram_extras
- (id) init {
    TRUNUSED CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();

    Spline c1, c2, c3;
    c1.addKnot(Spline::Knot(0, 0) / 255.0);
    c1.addKnot(Spline::Knot(64, 32) / 255.0);
    c1.addKnot(Spline::Knot(192, 224) / 255.0);
    c1.addKnot(Spline::Knot(255, 255) / 255.0);
    
    c2.addKnot(Spline::Knot(0, 0) / 255.0);
    c2.addKnot(Spline::Knot(128, 128) / 255.0);
    c2.addKnot(Spline::Knot(255, 205) / 255.0);

    c3.addKnot(Spline::Knot(0, 50) / 255.0);
    c3.addKnot(Spline::Knot(128, 128) / 255.0);
    c3.addKnot(Spline::Knot(255, 255) / 255.0);
    
    contrastcurve = [TRCurves newWithInput:nil rgb:c1];
    highlightcurve = [TRCurves newWithInput:nil rgb:c2];
    [highlightcurve setStrength:@0.45];
    shadowcurve = [TRCurves newWithInput:nil rgb:c3];
    [shadowcurve setStrength:@0.8];

    TRUNUSED CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    DDLogVerbose(@"TRinstagram_extras init took %0.3f seconds", end - start);

    return self;
}
- (id) copyWithZone:(NSZone*)zone {
    return self;
}
@end

/*
blur1: blur(in)    # was blur
    radius: 0.025

usm1: usm(in, blur1)    # was usm
    amount: 0.35 snapamount "Snap"

standardgrey: greymix(usm1)

desaturate: blend(usm1, standardgrey)
    amount: 0.2 desatamount "Saturation"

contrastcurve: curves(desaturate)
    rgb: 0,0; 64,32; 192,224; 255,255
    amount: 1.0 contrast "Contrast"

highlightcurve: curves(contrastcurve)
    rgb: 0,0; 128,128; 255,205
    amount: 0.45 highlights1 "Highlight Fade"

shadowcurve: curves(highlightcurve)
    rgb: 0,50; 128,128; 255,255
    amount: 0.8 shadows1 "Shadow Fade"

brighten: blend(shadowcurve, shadowcurve)
    mode: SCREEN
    amount: 0.05 brightnessamount "Brightness Boost"

out(brighten)
*/

@implementation TRinstagram
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.instagram"
      name:@"Pier Pressure" group:@"Follow Us" code:@"Ig"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Effect Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1],
          nil];
    }
    return self;
}

- (CIImage*) applyTo:(CIImage*)input {
    NSAssert(input, @"TRinstagram applyTo input is nil");

    TRinstagram_extras* extras = [TRStylet preflightObjectForIdent:self.ident];
    if (!extras) {
        extras = [[TRinstagram_extras alloc] init];
        [TRStylet setPreflightObject:extras forIdent:self.ident];
    }

    TRRollup* rollup = nil;

    @autoreleasepool {
        TRUnsharpMask* usm1 = [TRUnsharpMask newWithInput:input radius:@0.025 amount:@0.35];

        TRGreyMix* standardgrey = [TRGreyMix newWithInput:usm1.outputImage];

        TRBlend* desaturate = [TRBlend newWithInput:standardgrey.outputImage background:usm1.outputImage
          mode:NORMAL strength:@0.2];

        TRCurves* constrastcurve = [extras->contrastcurve copy];
        constrastcurve.inputImage = desaturate.outputImage;

        TRCurves* highlightcurve = [extras->highlightcurve copy];
        highlightcurve.inputImage = constrastcurve.outputImage;

        TRCurves* shadowcurve = [extras->shadowcurve copy];
        shadowcurve.inputImage = highlightcurve.outputImage;

        rollup = [TRRollup newWithInput:shadowcurve.outputImage];
    }

    TRBlend* brighten = [TRBlend newWithInput:rollup.outputImage background:rollup.outputImage
      mode:SCREEN strength:@0.05];

    CIImage* result = brighten.outputImage;
    NSAssert(result, @"TRinstagram applyTo result is nil");
    return result;
}
@end
