#import "TRFilter.h"

static int ddLogLevel = LOG_LEVEL_INFO;

@implementation TRSolidColor
@synthesize inputSize;
@synthesize inputColor;

+ (TRSolidColor*) newWithR:(float)red G:(float)green B:(float)blue
  size:(CGSize)inputSize {
    TRSolidColor* result = [[TRSolidColor alloc] init];
    NSAssert(result, @"TRSolidColor newWithR:G:B result is nil");
    result.inputColor = [CIColor colorWithRed:red green:green blue:blue];
    result.inputSize = inputSize;
    return result;
}

- (CIImage*) outputImage {
    CIFilter* color = [CIFilter filterWithName:@"CIConstantColorGenerator"];
    NSAssert(color, @"TRSolidColor outputImage color is nil");
    [color setDefaults];
    [color setValue:inputColor forKey:@"inputColor"];
    
    CIFilter* crop = [CIFilter filterWithName:@"CICrop"];
    NSAssert(crop, @"TRSolidColor outputImage crop is nil");
    [crop setDefaults];
    [crop setValue:color.outputImage forKey:@"inputImage"];
    [crop setValue:[CIVector vectorWithX:0 Y:0 Z:inputSize.width W:inputSize.height]
      forKey:@"inputRectangle"];

    CIImage* result = crop.outputImage;
    NSAssert(result, @"TRSolidColor outputImage result is nil");
    return result;
}

- (void)setNilValueForKey:(NSString*)key {
    DDLogVerbose(@"TRSolidColor setNilValueForKey %@", key);
    if ([key isEqualToString:@"inputSize"]) {
        inputSize = CGSizeZero;
    } else {
        [super setNilValueForKey:key];
    }
}

@end
