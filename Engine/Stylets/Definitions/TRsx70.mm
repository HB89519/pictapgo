#import "TRStylet.h"

static int ddLogLevel = LOG_LEVEL_INFO;

using tr::util::Spline;

@interface TRsx70_extras : NSObject {
@package
    TRCurves* curves1;
    TRCurves* curves2;
    TRLevels* levels1;
    TRLevels* levels2;
    TRHueSat* huesat1;
}
@end

@implementation TRsx70_extras
- (id) init {
    TRUNUSED CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();

    Spline rgb1;
    rgb1.addKnot(Spline::Knot(0, 0) / 255.0);
    rgb1.addKnot(Spline::Knot(13, 6) / 255.0);
    rgb1.addKnot(Spline::Knot(240, 249) / 255.0);
    rgb1.addKnot(Spline::Knot(255, 255) / 255.0);
    curves1 = [TRCurves newWithInput:nil rgb:rgb1];

    Spline rgb2, r2, g2, b2;
    rgb2.addKnot(Spline::Knot(0, 0) / 255.0);
    rgb2.addKnot(Spline::Knot(54, 63) / 255.0);
    rgb2.addKnot(Spline::Knot(226, 249) / 255.0);
    rgb2.addKnot(Spline::Knot(255, 255) / 255.0);
    r2 = Spline::ident();
    g2.addKnot(Spline::Knot(0, 0) / 255.0);
    g2.addKnot(Spline::Knot(114, 113) / 255.0);
    g2.addKnot(Spline::Knot(220, 228) / 255.0);
    g2.addKnot(Spline::Knot(255, 255) / 255.0);
    b2.addKnot(Spline::Knot(0, 0) / 255.0);
    b2.addKnot(Spline::Knot(128, 133) / 255.0);
    b2.addKnot(Spline::Knot(218, 226) / 255.0);
    b2.addKnot(Spline::Knot(255, 255) / 255.0);
    curves2 = [TRCurves newWithInput:nil rgb:rgb2 r:r2 g:g2 b:b2];

    LevelsAdjustments adj1;
    adj1.adj[3].outMin = 22;
    adj1.adj[3].outMax = 233;
    adj1.adj[3].gamma = 1.23;
    levels1 = [TRLevels newWithInput:nil levels:adj1];

    LevelsAdjustments adj2;
    adj2.adj[0].outMin = 13;
    adj2.adj[0].outMax = 255;
    adj2.adj[1].outMin = 0;
    adj2.adj[1].outMax = 246;
    adj2.adj[2].outMin = 0;
    adj2.adj[2].outMax = 218;
    adj2.adj[2].gamma = 1.11;
    levels2 = [TRLevels newWithInput:nil levels:adj2];

    HueSatAdjustments hs;
    hs.slices.push_back(HueSatAdjustments::Slice(0,0,0,0,        0, -0.13, 0));
    hs.slices.push_back(HueSatAdjustments::Slice(315,345,15,45, -3,     0, 0));
    hs.slices.push_back(HueSatAdjustments::Slice(15,45,75,105,   0, -0.13, 0));
    huesat1 = [TRHueSat newWithInput:nil hueSat:hs];
    
    TRUNUSED CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    DDLogVerbose(@"TRsx70_extras init took %0.3f seconds", end - start);
    
    return self;
}
- (id) copyWithZone:(NSZone*)zone {
    return self;
}
@end

@implementation TRsx70
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.sx70"
      name:@"SX-70" group:@"Vintage Color" code:@"Sx"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1.0],
          nil];
    }
    return self;
}
- (CIImage*) applyTo:(CIImage*)input {
    TRsx70_extras* extras = [TRStylet preflightObjectForIdent:self.ident];
    if (!extras) {
        extras = [[TRsx70_extras alloc] init];
        [TRStylet setPreflightObject:extras forIdent:self.ident];
    }

    CIImage* result = nil;
    @autoreleasepool {
        TRLevels* levels2 = nil;
        @autoreleasepool {
            TRLevels* levels1 = nil;
            @autoreleasepool {
                TRCurves* curves2 = nil;
                @autoreleasepool {
                    TRBlend* contrastluma = nil;
                    @autoreleasepool {
                        TRBlend* bigblurblend1 = nil;
                        @autoreleasepool {
                            TRRollup* smallblurblend = nil;
                            @autoreleasepool {
                                TRBlur* smallblur = [TRBlur newWithInput:input radius:@0.0003];
                                TRBlend* smallblurblend1 = [TRBlend newWithInput:smallblur.outputImage background:input
                                  mode:NORMAL strength:@0.65];
                                smallblurblend = [TRRollup newWithInput:smallblurblend1.outputImage];
                            }

                            TRBlur* bigblur = [TRBlur newWithInput:smallblurblend.outputImage radius:@0.0025];
                            bigblurblend1 = [TRBlend newWithInput:bigblur.outputImage background:smallblurblend.outputImage
                              mode:NORMAL strength:@0.2];
                        }

                        TRRollup* bigblurblend = [TRRollup newWithInput:bigblurblend1.outputImage];
                        bigblurblend1 = nil;

                        TRCurves* curves1 = [extras->curves1 copy];
                        curves1.inputImage = bigblurblend.outputImage;

                        contrastluma = [TRBlend newWithInput:curves1.outputImage background:bigblurblend.outputImage
                          mode:LUMINOSITY];
                    }

                    curves2 = [extras->curves2 copy];
                    curves2.inputImage = contrastluma.outputImage;
                }

                levels1 = [extras->levels1 copy];
                levels1.inputImage = curves2.outputImage;
            }

            levels2 = [extras->levels2 copy];
            levels2.inputImage = levels1.outputImage;
        }

        TRHueSat* huesat1 = [extras->huesat1 copy];
        huesat1.inputImage = levels2.outputImage;
        result = huesat1.outputImage;
    }

    return result;
}
@end

