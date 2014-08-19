#import "TRFilter.h"
#import <Accelerate/Accelerate.h>

@implementation TRAutoColor
@synthesize inputImage;

+ (TRAutoColor*) newWithInput:(CIImage*)input {
    TRAutoColor* result = [[TRAutoColor alloc] init];
    NSAssert(result, @"TRAutoColor newWithInput returned nil");
    result.inputImage = input;
    return result;
}

- (vImage_Error)runVImageOperation:(vImage_Buffer*)input
  output:(vImage_Buffer*)output {
    unsigned int percent_low[4] = { 1, 1, 1, 1 };
    unsigned int percent_high[4] = { 1, 1, 1, 1 };
    vImage_Error err = vImageEndsInContrastStretch_ARGB8888(input, output,
      percent_low, percent_high, kvImageNoFlags);
    return err;
}

@end
