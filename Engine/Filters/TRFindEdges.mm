#if 0
// XXX commented out by Tim, 2013-02-19.  Dead code right now, and causes
// complaints from code analysis.
#import "TRFilter.h"
#import <Accelerate/Accelerate.h>

@implementation TRFindEdges
@synthesize inputImage;

+ (TRFindEdges*) newWithInput:(CIImage*)input {
    TRFindEdges* result = [[TRFindEdges alloc] init];
    NSAssert(result, @"TRFindEdges newWithInput result is nil");
    result.inputImage = input;
    return result;
}

- (vImage_Error)runVImageOperation:(vImage_Buffer*)input
  output:(vImage_Buffer*)output {
    const size_t floatRowBytes = input->width * sizeof(Pixel_F) * 4;
    const size_t floatBufferBytes = floatRowBytes * input->height;
    Pixel_F* hEdgesBuffer = (Pixel_F*)malloc(floatBufferBytes);
    NSAssert(hEdgesBuffer, @"TRFindEdges runVImageOperation hEdgesBuffer is nil");
    Pixel_F* vEdgesBuffer = (Pixel_F*)malloc(floatBufferBytes);
    NSAssert(hEdgesBuffer, @"TRFindEdges runVImageOperation vEdgesBuffer is nil");

    vImage_Buffer hEdges;
    hEdges.width = input->width;
    hEdges.height = input->height;
    hEdges.rowBytes = floatRowBytes;
    hEdges.data = hEdgesBuffer;

    vImage_Buffer vEdges;
    vEdges.width = input->width;
    vEdges.height = input->height;
    vEdges.rowBytes = floatRowBytes;
    vEdges.data = vEdgesBuffer;

    // Maybe do this all in float range 0..255??
    vImage_Error err;
    err = vImageConvert_Planar8toPlanarF(input, &vEdges, 1.0f, 0.0f, kvImageNoFlags);
    NSAssert(!err, @"TRFindEdges runVImageOperation Planar8toPlanarF vEdges err=%d", err);
    err = vImageConvert_Planar8toPlanarF(input, &hEdges, 1.0f, 0.0f, kvImageNoFlags);
    NSAssert(!err, @"TRFindEdges runVImageOperation Planar8toPlanarF hEdges err=%d", err);

    float vKernel[9] = { -1/255.0, 0, 1/255.0, -2/255.0, 0, 2/255.0, -1/255.0, 0, 1/255.0 };
    float hKernel[9] = { -1/255.0, -2/255.0, -1/255.0, 0, 0, 0, 1/255.0, 2/255.0, 1/255.0 };

    Pixel_FFFF bgColor = { 0, 0, 0, 0 };
    vImage_Flags flags = kvImageEdgeExtend;

    err = vImageConvolve_ARGBFFFF(input, &hEdges, NULL, 0, 0,
      hKernel, 3, 3, bgColor, flags);
    NSAssert(!err, @"TRFindEdges runVImageOperation Convolve hEdges err=%d", err);

    err = vImageConvolve_ARGBFFFF(input, &vEdges, NULL, 0, 0,
      vKernel, 3, 3, bgColor, flags);
    NSAssert(!err, @"TRFindEdges runVImageOperation Convolve vEdges err=%d", err);

    const size_t outputRowBytes = output->width * sizeof(Pixel_8) * 4;
    const size_t outputBufferBytes = outputRowBytes * output->height;
    Pixel_8* o = (Pixel_8*)output->data;
    Pixel_8* end = o + outputBufferBytes;
    Pixel_F* i1 = vEdgesBuffer;
    Pixel_F* i2 = hEdgesBuffer;
    for ( ; o != end; ++o, ++i1, ++i2) {
        Pixel_F p1 = *i1;
        Pixel_F p2 = *i2;
        float p = sqrtf(p1 * p1 + p2 * p2);
        Pixel_8 v = (Pixel_8)(255.0 * p);
        *o = v;
    }

    free(hEdgesBuffer);
    free(vEdgesBuffer);

    return err;
}

@end
#endif