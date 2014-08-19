#include "TRStylet.h"

@implementation TRdarken
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.darken"
      name:@"Exposure -½" group:@"Basic Adjustments" code:@"Dk"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1.0],
          nil];
    }
    return self;
}
- (CIImage*) applyTo:(CIImage*)input {
    CIFilter* filt = [CIFilter filterWithName:@"CIExposureAdjust"];
    NSAssert(filt, @"TRdarken applyTo filt is nil");
    [filt setDefaults];
    [filt setValue:input forKey:@"inputImage"];
    [filt setValue:[NSNumber numberWithFloat:-0.5] forKey:@"inputEV"];

    CIImage* result = filt.outputImage;
    NSAssert(result, @"TRdarken applyTo result is nil");
    return result;
}
@end

