#import "TRStylet.h"

static int ddLogLevel = LOG_LEVEL_INFO;

@interface TRmason_extras : NSObject {
@package
    TRCube* cube;
}
@end

@implementation TRmason_extras
- (id) init {
    TRUNUSED CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    cube = [TRCube newWithInput:nil cubeFile:@"cube-mason" size:16];
    TRUNUSED CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    DDLogVerbose(@"TRmason_extras init took %0.3f seconds", end - start);

    return self;
}
- (id) copyWithZone:(NSZone*)zone {
    return self;
}
@end

@implementation TRmason
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.mason"
      name:@"Mason" group:@"Clones" code:@"Ms"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Effect Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1],
          nil];
    }
    return self;
}

- (CIImage*) applyTo:(CIImage*)input {
    TRmason_extras* extras = [TRStylet preflightObjectForIdent:self.ident];
    if (!extras) {
        extras = [[TRmason_extras alloc] init];
        [TRStylet setPreflightObject:extras forIdent:self.ident];
    }
    TRCube* cube = [extras->cube copy];
    cube.inputImage = input;
    return cube.outputImage;
}
@end
