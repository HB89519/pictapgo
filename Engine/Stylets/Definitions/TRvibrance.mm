#include "TRStylet.h"

@implementation TRvibrance
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.vibrance"
      name:@"Vibrance" group:@"Basic Adjustments" code:@"Vb"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1.0],
          nil];
    }
    return self;
}
- (CIImage*) applyTo:(CIImage*)input {
    CIFilter* filt = [CIFilter filterWithName:@"CIVibrance"];
    NSAssert(filt, @"TRvibrance applyTo filt is nil");
    [filt setDefaults];
    [filt setValue:input forKey:@"inputImage"];
    [filt setValue:[NSNumber numberWithFloat:1.0] forKey:@"inputAmount"];
    return filt.outputImage;
}
@end

