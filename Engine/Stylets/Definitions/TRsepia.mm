#import "TRStylet.h"

@implementation TRsepia
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.sepia"
      name:@"Sepia" group:@"Basic Adjustments" code:@"#"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1.0],
          nil];
    }
    return self;
}
- (CIImage*) applyTo:(CIImage*)input {
    CIFilter* sepia = [CIFilter filterWithName:@"CISepiaTone"];
    NSAssert(sepia, @"TRsepia applyTo sepia is nil");
    [sepia setDefaults];
    [sepia setValue:input forKey:@"inputImage"];

    CIImage* result = sepia.outputImage;
    NSAssert(result, @"TRsepia applyTo result is nil");
    return result;
}
@end

