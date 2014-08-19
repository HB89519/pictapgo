#import "TRStylet.h"

static int ddLogLevel = LOG_LEVEL_INFO;
using tr::util::Spline;

@interface TRfacebook_extras : NSObject {
@package
    TRLevels* hlsoften;
    TRCurves* tonecurve;
    TRLevels* hlpinch;
}
@end

@implementation TRfacebook_extras
- (id) init {
    TRUNUSED CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();

    LevelsAdjustments adj1;
    adj1.adj[3].inMin = 10;
    adj1.adj[3].inMax = 255;
    adj1.adj[3].outMin = 0;
    adj1.adj[3].outMax = 190;
    adj1.adj[3].gamma = 1.3;
    hlsoften = [TRLevels newWithInput:nil levels:adj1];

    Spline rgb1;
    rgb1.addKnot(Spline::Knot(0, 0) / 255.0);
    rgb1.addKnot(Spline::Knot(46, 48) / 255.0);
    rgb1.addKnot(Spline::Knot(144, 201) / 255.0);
    rgb1.addKnot(Spline::Knot(255, 255) / 255.0);
    tonecurve = [TRCurves newWithInput:nil rgb:rgb1];

    LevelsAdjustments adj2;
    adj2.adj[3].outMin = 0;
    adj2.adj[3].outMax = 237;
    hlpinch = [TRLevels newWithInput:nil levels:adj2];

    TRUNUSED CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    DDLogVerbose(@"TRfacebook_extras init took %0.3f seconds", end - start);

    return self;
}
- (id) copyWithZone:(NSZone*)zone {
    return self;
}
@end

@implementation TRfacebook
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.facebook"
      name:@"Milk & Cookies" group:@"Follow Us" code:@"Fb"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Effect Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1],
          nil];
    }
    return self;
}

- (CIImage*) applyTo:(CIImage*)input {
    NSAssert(input, @"TRfacebook applyTo input is nil");

    TRfacebook_extras* extras = [TRStylet preflightObjectForIdent:self.ident];
    if (!extras) {
        extras = [[TRfacebook_extras alloc] init];
        [TRStylet setPreflightObject:extras forIdent:self.ident];
    }

    TRLevels* hlsoften = [extras->hlsoften copy];
    hlsoften.inputImage = input;

    TRGreyMix* desat = [TRGreyMix newWithInput:hlsoften.outputImage r:@0.4 g:@0.4 b:@0.2];

    TRCurves* tonecurve = [extras->tonecurve copy];
    tonecurve.inputImage = desat.outputImage;

    TRBlur* blur1 = [TRBlur newWithInput:tonecurve.outputImage radius:@0.035];

    TRHighPass* highpass1 = [TRHighPass newWithInput:tonecurve.outputImage blurredImage:blur1.outputImage];

    TRBlend* highpassblend = [TRBlend newWithInput:highpass1.outputImage background:tonecurve.outputImage
      mode:SOFT_LIGHT strength:@0.75];

    TRLevels* hlpinch = [extras->hlpinch copy];
    hlpinch.inputImage = highpassblend.outputImage;

    CIImage* result = hlpinch.outputImage;
    NSAssert(result, @"TRfacebook applyTo result is nil");
    return result;
}
@end
