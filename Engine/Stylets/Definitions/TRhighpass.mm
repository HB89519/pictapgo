#import "TRStylet.h"

@implementation TRhighpass
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.highpass"
      name:@"High Pass" group:@"Basic Adjustments" code:@"#"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"brightness" named:@"Brightness"
            value:0.5 uiMin:0.0 uiMax:100.0 actualMin:0 actualMax:1.0],
          nil];
    }
    return self;
}
- (CIImage*) applyTo:(CIImage*)input {
    TRBlur* blur = [TRBlur newWithInput:input radius:[NSNumber numberWithFloat:.001]];
    NSAssert(blur, @"TRhighpass applyTo blur is nil");
    TRHighPass* hp = [TRHighPass newWithInput:input blurredImage:blur.outputImage];
    NSAssert(hp, @"TRhighpass applyTo hp is nil");

    return hp.outputImage;
}
@end

