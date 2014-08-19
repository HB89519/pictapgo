#import "TRFilter.h"
#import "TRHelper.h"
#import "CIContext+SingleThreadedRendering.h"

@implementation TRFilter

- (CIImage*) outputImage {
    assert(!"expected subclass to override outputImage method");
}

@end

@implementation TRAccelerateFrameworkFilter

// To implement on big-endian architecture, need to figure out what args to
// pass to CGBitmapContextCreate
#ifdef __BIG_ENDIAN__
#error Accelerator Framework wrappers unimplemented on big-endian architecture
#endif

- (CGContextRef)newARGBBitmapContext:(CGSize)sz {
    size_t bitmapBytesPerRow = sz.width * 4;

    // Use the generic RGB color space.
    CGColorSpaceRef dRGB = CGColorSpaceCreateDeviceRGB();
    NSAssert(dRGB, @"TRAccelerateFrameworkFilter:newARGBBitmapContext dRGB is nil");

    // Create the bitmap context. We want pre-multiplied ARGB, 8-bits
    // per component. Regardless of what the source image format is 
    // (CMYK, Grayscale, and so on) it will be converted over to the format
    // specified here by CGBitmapContextCreate.
    //
    // XXX: sady, I (Tim) can't say for CERTAIN that this is the correct
    // order for vImage operations, but I've wrestled with it for more than
    // 2 days now and can't come up with an order that works consistently when
    // vImage operations use the kvImageLeaveAlphaUnchanged flag;
    CGContextRef context = CGBitmapContextCreate(NULL,
      sz.width, sz.height, 8, bitmapBytesPerRow, dRGB,
      kCGBitmapByteOrder32Host | kCGImageAlphaNoneSkipFirst);
    NSAssert(context, @"couldn't create ARGB CGBitmapContext");

    CGColorSpaceRelease(dRGB);

    return context;
}

- (vImage_Error) runVImageOperation:(vImage_Buffer*)input
  output:(vImage_Buffer*)output {
    assert(!"expected subclass to override runVImageOperation");
}

void CGBitmapReleaseUsingFree(void* releaseInfo, void* data) {
    free(data);
}

- (CIImage*)outputImage {
    vImage_Buffer outBuffer = {0, 0, 0, 0};
    {
        CGContextRef cgContext = nil;
        {
            // convert CIImage into a CGImage
            CGImageRef cgFromCi = nil;
            {
                CIContext* context = [TRHelper getCIContext];
                NSAssert(context, @"TRAccelerateFrameworkFilter outputImage context is nil");
                cgFromCi = [context createCGImageMoreSafely:self.inputImage
                  fromRect:self.inputImage.extent];
                NSAssert(cgFromCi, @"TRAccelerateFrameworkFilter outputImage cgFromCi is nil");
                [TRHelper doneWithCIContext:context];
            }

            // render CGImage into a CGContext in ARGB order
            cgContext = [self newARGBBitmapContext:self.inputImage.extent.size];
            CGContextDrawImage(cgContext, self.inputImage.extent, cgFromCi);
            CGImageRelease(cgFromCi);
        }

        // setup vImage descriptors
        vImage_Buffer inBuffer = {0, 0, 0, 0};
        inBuffer.width = CGBitmapContextGetWidth(cgContext);
        inBuffer.height = CGBitmapContextGetHeight(cgContext);
        inBuffer.rowBytes = CGBitmapContextGetBytesPerRow(cgContext);
        inBuffer.data = CGBitmapContextGetData(cgContext);

        size_t pixelBufferSize = inBuffer.rowBytes * inBuffer.height;
        void* pixelBuffer = malloc(pixelBufferSize + 16);
        if (!pixelBuffer) {
            CGContextRelease(cgContext);
            [NSException raise:@"AccelerateUsageError" format:@"couldn't allocate output buffer"];
        }
        outBuffer.width = inBuffer.width;
        outBuffer.height = inBuffer.height;
        outBuffer.rowBytes = inBuffer.rowBytes;
        outBuffer.data = pixelBuffer;

        // ------------------------------------------------------------
        // Run the actual vImage operation
        // ------------------------------------------------------------
        vImage_Error error = [self runVImageOperation:&inBuffer output:&outBuffer];
        if (error != kvImageNoError) {
            free(pixelBuffer);
            [NSException raise:@"AccelerateUsageError" format:@"vImage operation failed"];
        }
        CGContextRelease(cgContext);
    }

    // Copy into a CIImage result
    CGColorSpaceRef dRGB = CGColorSpaceCreateDeviceRGB();
    CGContextRef cgOutputCtx = CGBitmapContextCreateWithData(outBuffer.data,
      outBuffer.width, outBuffer.height, 8, outBuffer.rowBytes, dRGB,
      kCGBitmapByteOrder32Host | kCGImageAlphaNoneSkipFirst,
      &CGBitmapReleaseUsingFree, nil);
    NSAssert(cgOutputCtx, @"TRAccelerateFrameworkFilter outputImage cgOutputCtx is nil");
    CGImageRef cgOutput = CGBitmapContextCreateImage(cgOutputCtx);
    NSAssert(cgOutput, @"TRAccelerateFrameworkFilter outputImage cgOutput is nil");
    CGColorSpaceRelease(dRGB);

    CIImage* result = [CIImage imageWithCGImage:cgOutput];
    NSAssert(result, @"TRAccelerateFrameworkFilter outputImage result is nil");

    CGImageRelease(cgOutput);
    CGContextRelease(cgOutputCtx);

    return result;
}

@end