#import "TRFilter.h"
#import <Accelerate/Accelerate.h>

@implementation TREqualize
@synthesize inputImage;

+ (TREqualize*) newWithInput:(CIImage*)input {
    TREqualize* result = [[TREqualize alloc] init];
    NSAssert(result, @"TREqualize newWithInput result is nil");
    result.inputImage = input;
    return result;
}

- (vImage_Error) runVImageOperation:(vImage_Buffer*)input
  output:(vImage_Buffer*)output {
    return vImageEqualization_ARGB8888(input, output, kvImageNoFlags);
}

@end
