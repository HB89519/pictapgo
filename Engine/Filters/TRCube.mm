#include <ostream>
#import "TRFilter.h"
#import "TRRecipe.h"
#import "DDLog.h"

static const int ddLogLevel = LOG_LEVEL_INFO;

@implementation TRCube
@synthesize inputImage;

+ (NSData*)newCubeDataForSize:(size_t)size image:(CGImageRef)cube {
    NSAssert(size == 16, @"TRCube newCubeDataForSize size=%zd", size);

    TRUNUSED size_t bpp = CGImageGetBitsPerPixel(cube);
    TRUNUSED size_t bpc = CGImageGetBitsPerComponent(cube);
    TRUNUSED size_t bytesInRow = CGImageGetBytesPerRow(cube);
    TRUNUSED size_t width = CGImageGetWidth(cube);
    TRUNUSED size_t height = CGImageGetHeight(cube);
    TRUNUSED CGImageAlphaInfo alphaInfo = CGImageGetAlphaInfo(cube);
    NSAssert(width == 64 && height == 64 && bpp == 32 && bpc == 8,
      @"TRCube newCubeDataForSize width=%zd height=%zd bpp=%zd bpc=%zd",
      width, height, bpp, bpc);

    DDLogCVerbose(@"%zdx%zd bpp=%zd bpc=%zd bytesInRow=%zd a.inf=%zd",
      width, height, bpp, bpc, bytesInRow, alphaInfo);
    CGDataProviderRef provider = CGImageGetDataProvider(cube);
    CFDataRef bitmapData = CGDataProviderCopyData(provider);
    const UInt8* imageData = CFDataGetBytePtr(bitmapData);

    const size_t cubeDataSize = size * size * size * sizeof(float) * 4;
    float* cubeData = (float*)malloc(cubeDataSize);

    const UInt8* ii = imageData;
    for (int g0 = 0; g0 < size; g0 += 4) {
        for (int r = 0; r < size; ++r) {
            for (int g = g0; g < g0 + 4; ++g) {
                for (int b = 0; b < size; ++b) {
                    enum oColor { O_RED = 0, O_GREEN = 1, O_BLUE = 2, O_ALPHA = 3};
                    enum iColor { I_RED = 0, I_GREEN = 1, I_BLUE = 2, I_ALPHA = 3};
                    float* const oi = cubeData + (b * 256 + g * 16 + r) * 4;
                    oi[O_RED] = float(ii[I_RED]) / 255.0;
                    oi[O_GREEN] = float(ii[I_GREEN]) / 255.0;
                    oi[O_BLUE] = float(ii[I_BLUE]) / 255.0;
                    oi[O_ALPHA] = 1.0;
                    ii += 4;
                }
            }
        }
    }
    CFRelease(bitmapData);
    
    NSData* data = [NSData dataWithBytesNoCopy:cubeData length:cubeDataSize
      freeWhenDone:YES];
    NSAssert(data, @"TRcube newCubeDataForSize result is nil");
    return data;
}

+ (TRCube*) newWithInput:(CIImage*)inputImage
  cube:(CGImageRef)cube size:(NSUInteger)size
{
    TRCube* result = [[TRCube alloc] init];
    NSAssert(result, @"TRCube newWithInput result is nil");
    result.inputImage = inputImage;

    result->colorCubeSize = size;
    result->colorCube = [TRCube newCubeDataForSize:result->colorCubeSize image:cube];

    return result;
}

+ (TRCube*) newWithInput:(CIImage*)inputImage cubeFile:(NSString*)filename
  size:(NSUInteger)size
{
    /*
    NSBundle* myBundle = [NSBundle bundleForClass:[TRCube class]];
    DDLogInfo(@"myBundle \"%@\"", myBundle);

    NSString* path = [[NSBundle mainBundle] resourcePath];
    DDLogInfo(@"resourcePath \"%@\"", path);
    NSFileManager* fm = [NSFileManager defaultManager];
    NSError* error = [[NSError alloc] init];
    NSArray* names = [fm contentsOfDirectoryAtPath:path error:&error];
    DDLogInfo(@"names: %@", names);
    */

    NSBundle* myBundle = [NSBundle bundleForClass:[TRCube class]];
    NSString* pngPath = [myBundle pathForResource:filename ofType:@"png"];
    NSAssert(pngPath, @"TRCube newWithInput pngPath is nil");
    DDLogVerbose(@"pngPath %@", pngPath);
    CGDataProviderRef provider =
      CGDataProviderCreateWithFilename([pngPath fileSystemRepresentation]);
    NSAssert(provider, @"TRCube newWithInput provider is nil");

    CGImageRef img = CGImageCreateWithPNGDataProvider(provider, NULL, false,
      kCGRenderingIntentDefault);
    CGDataProviderRelease(provider);

    TRCube* result = [TRCube newWithInput:inputImage cube:img size:size];
    CGImageRelease(img);
    NSAssert(result, @"TRCube newWithInput result is nil");
    return result;
}

-(id)copyWithZone:(NSZone *)zone {
  TRCube *another = [[TRCube allocWithZone:zone] init];
  NSAssert(another, @"TRCube copyWithZone another is nil");
  another->inputImage = nil;
  another->colorCubeSize = colorCubeSize;
  another->colorCube = [colorCube copyWithZone:zone];
  return another;
}

- (CIImage*) outputImage {
    DDLogVerbose(@"TRCube outputImage");

    NSAssert(colorCube, @"TRCube colorCube is nil");
    NSAssert([colorCube isKindOfClass:[NSData class]], @"TRCube colorCube is not NSData!");

    CIFilter* cube = [CIFilter filterWithName:@"CIColorCube"];
    NSAssert(cube, @"TRCube outputImage cube is nil");
    [cube setDefaults];
    [cube setValue:inputImage forKey:@"inputImage"];
    [cube setValue:colorCube forKey:@"inputCubeData"];
    [cube setValue:[NSNumber numberWithLong:colorCubeSize]
      forKey:@"inputCubeDimension"];

    CIImage* result = cube.outputImage;
    NSAssert(result, @"TRCube outputImage result is nil for cube %@", cube);
    return result;
}

@end
