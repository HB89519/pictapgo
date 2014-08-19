#import "TRStylet.h"

static int ddLogLevel = LOG_LEVEL_INFO;

@implementation TRgrainstorm
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.grainstorm"
      name:@"Grainstorm" group:@"Basic Adjustments" code:@"G"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1.0],
          nil];
    }
    return self;
}
- (CIImage*) applyTo:(CIImage*)input {
    TRAddGrain* grain = [TRAddGrain newWithSize:input.extent.size
      graininess:[NSNumber numberWithFloat:0.15]];
    
    DDLogVerbose(@"Grainstorm strength %@", self.actualStrength);
    TRBlend* finalblend = [TRBlend newWithInput:grain.outputImage
      background:input mode:OVERLAY];
    
    return finalblend.outputImage;
}
@end

