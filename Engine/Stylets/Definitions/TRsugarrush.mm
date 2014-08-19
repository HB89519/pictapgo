#import "TRStylet.h"

static int ddLogLevel = LOG_LEVEL_INFO;

@interface TRsugarrush_extras : NSObject {
@package
    TRHueSat* huesat1;
}
@end

@implementation TRsugarrush_extras
- (id) init {
    TRUNUSED CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    
    HueSatAdjustments adj2;
    adj2.slices.push_back(HueSatAdjustments::Slice(315,345,25,45, 0, -0.9, 0));
    huesat1 = [TRHueSat newWithInput:nil hueSat:adj2];
    
    TRUNUSED CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    DDLogVerbose(@"TRsugarrush_extras init took %0.3f seconds", end - start);
    
    return self;
}
- (id) copyWithZone:(NSZone*)zone {
    return self;
}
@end

@implementation TRsugarrush
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.sugarrush"
      name:@"Sugar Rush" group:@"Basic Adjustments" code:@"Sr"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1.0],
          [TRNumberKnob newKnobIdentifiedBy:@"variation" named:@"Variation"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:360],
          nil];
    }
    return self;
}
- (CIImage*) applyTo:(CIImage*)input {
    TRsugarrush_extras* extras = [TRStylet preflightObjectForIdent:self.ident];
    if (!extras) {
        extras = [[TRsugarrush_extras alloc] init];
        [TRStylet setPreflightObject:extras forIdent:self.ident];
    }

    CIImage* wheelImg = input;
    if ([[self valueForKnob:@"variation"] floatValue] != 0) {
        HueSatAdjustments adj1;
        adj1.slices.push_back(HueSatAdjustments::Slice(0,0,0,0,
          [[self valueForKnob:@"variation"] floatValue], 0, 0));
        TRHueSat* wheel = [TRHueSat newWithInput:input hueSat:adj1];
        wheelImg = wheel.outputImage;
    }
    
    TRGreyMix* desat = [TRGreyMix newWithInput:wheelImg r:[NSNumber numberWithFloat:0.2]
      g:[NSNumber numberWithFloat:0.2] b:[NSNumber numberWithFloat:0.6]];
    
    TRHighPass* highpass1 =
      [TRHighPass newWithInput:input blurredImage:desat.outputImage];
    
    TRHueSat* huesat1 = extras->huesat1;
    huesat1.inputImage = highpass1.outputImage;
    
    TRBlend* finalblend = [TRBlend newWithInput:huesat1.outputImage background:input
      mode:SOFT_LIGHT strength:[NSNumber numberWithFloat:1.25]];
    
    return finalblend.outputImage;
}
@end

