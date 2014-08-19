#import "TRFilter.h"
#import "TRHelper.h"
#import "CIContext+SingleThreadedRendering.h"

@implementation TRRollup {
    CIImage* rollup;
}

@synthesize inputImage;

+ (TRRollup*) newWithInput:(CIImage*)input {
    TRRollup* result = [[TRRollup alloc] init];
    NSAssert(result, @"TRRollup newWithInput result is nil");
    result->rollup = nil;
    result.inputImage = input;
    return result;
}

- (CIImage*) outputImage {
    @synchronized (self) {
        if (!rollup) {
            CIContext* context = [TRHelper getCIContext];
            NSAssert(context, @"TRRollup outputImage context is nil");

            CGImageRef cgImg = [context createCGImageMoreSafely:inputImage fromRect:inputImage.extent];
            NSAssert(cgImg, @"TRRollup outputImage cgImg is nil");
            rollup = [CIImage imageWithCGImage:cgImg];
            NSAssert(rollup, @"TRRollup outputImage rollup is nil");
            CGImageRelease(cgImg);

            [TRHelper doneWithCIContext:context];
        }
        return rollup;
    }
}

@end
