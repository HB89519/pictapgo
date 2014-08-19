#import "TRStylet.h"

static int ddLogLevel = LOG_LEVEL_INFO;

using tr::util::Spline;

@interface TRflirt_extras : NSObject {
@package
    TRCurves* curves1;
    TRHueSat* huesat1;
}
@end

@implementation TRflirt_extras
- (id) init {
    TRUNUSED CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    Spline rgb, r, g, b;
    rgb.addKnot(Spline::Knot(0, 0) / 255.0);
    rgb.addKnot(Spline::Knot(155, 193) / 255.0);
    rgb.addKnot(Spline::Knot(250, 240) / 255.0);
    
    r.addKnot(Spline::Knot(10, 0) / 255.0);
    r.addKnot(Spline::Knot(64, 64) / 255.0);
    r.addKnot(Spline::Knot(121, 123) / 255.0);
    r.addKnot(Spline::Knot(223, 240) / 255.0);
    r.addKnot(Spline::Knot(255, 255) / 255.0);
    
    g.addKnot(Spline::Knot(0, 0) / 255.0);
    g.addKnot(Spline::Knot(214, 210) / 255.0);
    g.addKnot(Spline::Knot(255, 248) / 255.0);
    
    b.addKnot(Spline::Knot(0, 0) / 255.0);
    b.addKnot(Spline::Knot(212, 208) / 255.0);
    b.addKnot(Spline::Knot(255, 246) / 255.0);
    
    curves1 = [TRCurves newWithInput:nil rgb:rgb r:r g:g b:b];
    
    HueSatAdjustments adj;
    adj.slices.push_back(
      HueSatAdjustments::Slice(288,318,348,18,  -7,  0.13,  0.26));
    adj.slices.push_back(
      HueSatAdjustments::Slice(40,54,72,102,    -6, -0.04,  0.62));
    adj.slices.push_back(
      HueSatAdjustments::Slice(19,49,91,168,     8,  0.02,  0));
    adj.slices.push_back(
      HueSatAdjustments::Slice(177,207,237,267, -6,  0.05, -0.03));
    adj.slices.push_back(
      HueSatAdjustments::Slice(333,3,33,63,      0, -0.11,  0));
    huesat1 = [TRHueSat newWithInput:nil hueSat:adj];
    
    TRUNUSED CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    DDLogVerbose(@"TRflirt_extras init took %0.3f seconds", end - start);
    
    return self;
}
- (id) copyWithZone:(NSZone*)zone {
    return self;
}
@end

@implementation TRflirt
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.flirt"
      name:@"Flirt" group:@"Vintage Color" code:@"Fl"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1.0],
          nil];
    }
    return self;
}
- (CIImage*) applyTo:(CIImage*)input {
    TRflirt_extras* extras = [TRStylet preflightObjectForIdent:self.ident];
    if (!extras) {
        extras = [[TRflirt_extras alloc] init];
        [TRStylet setPreflightObject:extras forIdent:self.ident];
    }

    TRCurves* curves1 = [extras->curves1 copy];
    NSAssert(curves1, @"TRflirt applyTo curves1 is nil");
    curves1.inputImage = input;
    TRHueSat* huesat1 = [extras->huesat1 copy];
    NSAssert(huesat1, @"TRflirt applyTo huesat1 is nil");
    huesat1.inputImage = curves1.outputImage;

    CIImage* result = huesat1.outputImage;
    NSAssert(result, @"TRflirt applyTo result is nil");
    return result;
}
@end

