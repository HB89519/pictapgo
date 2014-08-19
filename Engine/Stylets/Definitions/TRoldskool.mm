#import "TRStylet.h"

static int ddLogLevel = LOG_LEVEL_INFO;

using tr::util::Spline;

@interface TRoldskool_extras : NSObject {
@package
    TRLevels* gradmask;
    TRCurves* midtonebump;
    TRCurves* toning;
    TRCurves* contrast;
}
@end

@implementation TRoldskool_extras
- (id) init {
    TRUNUSED CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();

    LevelsAdjustments adj1;
    adj1.adj[0].outMin = 255;
    adj1.adj[0].outMax = 0;
    adj1.adj[1].outMin = 255;
    adj1.adj[1].outMax = 0;
    adj1.adj[2].outMin = 255;
    adj1.adj[2].outMax = 0;
    adj1.adj[3].gamma = 0.25;
    gradmask = [TRLevels newWithInput:nil levels:adj1];

    Spline rgb1;
    rgb1.addKnot(Spline::Knot(0, 0) / 255.0);
    rgb1.addKnot(Spline::Knot(24, 45) / 255.0);
    rgb1.addKnot(Spline::Knot(255, 255) / 255.0);
    midtonebump = [TRCurves newWithInput:nil rgb:rgb1];

    Spline rgb2, r1, g1, b1;
    rgb2 = Spline::ident();
    r1.addKnot(Spline::Knot(0, 12) / 255.0);
    r1.addKnot(Spline::Knot(255, 255) / 255.0);
    g1.addKnot(Spline::Knot(0, 0) / 255.0);
    g1.addKnot(Spline::Knot(255, 250) / 255.0);
    b1.addKnot(Spline::Knot(0, 0) / 255.0);
    b1.addKnot(Spline::Knot(255, 225) / 255.0);
    toning = [TRCurves newWithInput:nil rgb:rgb2 r:r1 g:g1 b:b1];

    Spline rgb3;
    rgb3.addKnot(Spline::Knot(0, 16) / 255.0);
    rgb3.addKnot(Spline::Knot(38, 50) / 255.0);
    rgb3.addKnot(Spline::Knot(188, 192) / 255.0);
    rgb3.addKnot(Spline::Knot(255, 230) / 255.0);
    contrast = [TRCurves newWithInput:nil rgb:rgb3];

    TRUNUSED CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    DDLogVerbose(@"TRoldskool_extras init took %0.3f seconds", end - start);
    
    return self;
}
@end

@implementation TRoldskool
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.oldskool"
      name:@"Old Skool" group:@"Black and White" code:@"Sk"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1.0],
          nil];
    }
    return self;
}
- (CIImage*) applyTo:(CIImage*)input {
    //TRGreyMix* standardgrey = [TRGreyMix newWithInput:input];
    TRoldskool_extras* extras = [TRStylet preflightObjectForIdent:self.ident];
    if (!extras) {
        extras = [[TRoldskool_extras alloc] init];
        [TRStylet setPreflightObject:extras forIdent:self.ident];
    }
    NSAssert(extras, @"TRoldskool applyTo extras is nil");

    CIImage* result = nil;
    @autoreleasepool {
        TRCurves* contrast = nil;
        @autoreleasepool {
            TRCurves* toning = nil;
            @autoreleasepool {
                TRRollup* rollup = nil;
                @autoreleasepool {
                    TRLevels* gradmask = nil;
                    @autoreleasepool {
                        TRGradient* grad = [TRGradient newWithInput:input
                          radius:[NSNumber numberWithFloat:1.0] masterSize:self.masterSize];
                        NSAssert(grad, @"TRoldskool applyTo grad is nil");

                        gradmask = [extras->gradmask copy];
                        NSAssert(gradmask, @"TRoldskool applyTo gradmask is nil");
                        gradmask.inputImage = grad.outputImage;
                    }

                    TRCurves* midtonebump = nil;
                    @autoreleasepool {
                        TRRollup* highpass_rollup = nil;
                        @autoreleasepool {
                            CIImage* blur1_output = nil;
                            @autoreleasepool {
                                TRBlur* blur1v = [TRBlur newWithInput:input
                                  radius:[NSNumber numberWithFloat:0.01]];

                                CIFilter* blur1 = [CIFilter filterWithName:@"CIBlendWithMask"];
                                NSAssert(blur1, @"TRoldskool applyTo blur1 is nil");
                                [blur1 setDefaults];
                                [blur1 setValue:blur1v.outputImage forKey:@"inputImage"];
                                [blur1 setValue:input forKey:@"inputBackgroundImage"];
                                [blur1 setValue:gradmask.outputImage forKey:@"inputMaskImage"];
                                blur1_output = blur1.outputImage;
                            }

                            TRBlur* highpassblur = [TRBlur newWithInput:input
                              radius:[NSNumber numberWithFloat:0.012]];
                            NSAssert(highpassblur, @"TRoldskool applyTo highpassblur is nil");

                            TRBlend* highpassblend = [TRBlend newWithInput:highpassblur.outputImage
                              background:blur1_output mode:OVERLAY
                              strength:[NSNumber numberWithFloat:0.15]];
                            NSAssert(highpassblend, @"TRoldskool applyTo highpassblend is nil");

                            highpass_rollup = [TRRollup newWithInput:highpassblend.outputImage];
                            NSAssert(highpass_rollup, @"TRoldskool applyTo highpass_rollup is nil");
                        }

                        CIFilter* gradinvert = [CIFilter filterWithName:@"CIColorInvert"];
                        NSAssert(gradinvert, @"TRoldskool applyTo gradinvert is nil");
                        [gradinvert setValue:gradmask.outputImage forKey:@"inputImage"];
                        gradmask = nil;

                        @autoreleasepool {
                            TRBlend* vignette = [TRBlend newWithInput:gradinvert.outputImage
                              background:highpass_rollup.outputImage mode:MULTIPLY
                              strength:[NSNumber numberWithFloat:1.0]];
                            NSAssert(vignette, @"TRoldskool applyTo vignette is nil");
                            midtonebump = [extras->midtonebump copy];
                            NSAssert(midtonebump, @"TRoldskool applyTo midtonebump is nil");
                            midtonebump.inputImage = vignette.outputImage;
                        }
                    }

                    TRGreyMix* orthobw = [TRGreyMix newWithInput:midtonebump.outputImage
                      mix:[CIVector vectorWithX:0.06 Y:0.06 Z:0.86 W:-0.08]];
                    NSAssert(orthobw, @"TRoldskool applyTo orthobw is nil");

                    rollup = [TRRollup newWithInput:orthobw.outputImage];
                    NSAssert(rollup, @"TRoldskool applyTo rollup is nil");
                }

                toning = [extras->toning copy];
                NSAssert(toning, @"TRoldskool applyTo toning is nil");
                toning.inputImage = rollup.outputImage;
            }

            contrast = [extras->contrast copy];
            NSAssert(contrast, @"TRoldskool applyTo contrast is nil");
            contrast.inputImage = toning.outputImage;
        }

        TRAddGrain* grain = [TRAddGrain newWithSize:input.extent.size
          graininess:[NSNumber numberWithFloat:0.1]];
        NSAssert(grain, @"TRoldskool applyTo grain is nil");

        TRBlend* grainblend = [TRBlend newWithInput:grain.outputImage
          background:contrast.outputImage mode:OVERLAY
          strength:[NSNumber numberWithFloat:1.0]];
        NSAssert(grainblend, @"TRoldskool applyTo grainblend is nil");
        contrast = nil;
        grain = nil;

        result = grainblend.outputImage;
        NSAssert(result, @"TRoldskool applyTo result is nil");
    }

    return result;
}
@end
