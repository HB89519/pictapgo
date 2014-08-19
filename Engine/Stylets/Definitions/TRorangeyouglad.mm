#import "TRStylet.h"

static int ddLogLevel = LOG_LEVEL_INFO;

@interface TRorangeyouglad_extras : NSObject {
@package
    TRHueSat* sat;
}
@end

@implementation TRorangeyouglad_extras
- (id) init {
    TRUNUSED CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    
    HueSatAdjustments adj;
    adj.slices.push_back(
      HueSatAdjustments::Slice(0, 0, 0, 0, 0, 0.5, 0));
    adj.slices.push_back(
      HueSatAdjustments::Slice(315, 345, 15, 45, 0, -0.15, 0));
    sat = [TRHueSat newWithInput:nil hueSat:adj];
    
    TRUNUSED CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    DDLogVerbose(@"TRorangeyouglad_extras init took %0.3f seconds", end - start);
    
    return self;
}
- (id) copyWithZone:(NSZone*)zone {
    return self;
}
@end

@implementation TRorangeyouglad
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.orangeyouglad"
      name:@"Orange You Glad" group:@"Basic Adjustments" code:@"Rg"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1.0],
          nil];
    }
    return self;
}
- (CIImage*) applyTo:(CIImage*)input {
    TRorangeyouglad_extras* extras = [TRStylet preflightObjectForIdent:self.ident];
    if (!extras) {
        extras = [[TRorangeyouglad_extras alloc] init];
        [TRStylet setPreflightObject:extras forIdent:self.ident];
    }

    TRChannelMix* chmix = [TRChannelMix newWithInput:input
      r:[CIVector vectorWithX:0.5 Y:0.5 Z:0.0]
      g:[CIVector vectorWithX:0.0 Y:1.0 Z:0.0]
      b:[CIVector vectorWithX:0.0 Y:0.5 Z:0.5]];

    TRHueSat* sat = extras->sat;
    sat.inputImage = chmix.outputImage;

    return sat.outputImage;
}
@end
