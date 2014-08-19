#import "TRStylet.h"

static int ddLogLevel = LOG_LEVEL_INFO;

@interface TRReplichromeTriX_extras : NSObject {
@package
    TRCube* cube;
}
@end

@implementation TRReplichromeTriX_extras
- (id) init {
    TRUNUSED CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    cube = [TRCube newWithInput:nil cubeFile:@"cube-replichrome-trix" size:16];
    TRUNUSED CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    DDLogVerbose(@"TRReplichromeTriX_extras init took %0.3f seconds", end - start);

    return self;
}
- (id) copyWithZone:(NSZone*)zone {
    return self;
}
@end

@implementation TRReplichromeTriX
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.replichrome-trix"
      name:@"Tri-X 400" group:@"Clones" code:@"Xri"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Effect Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1],
          nil];
    }
    return self;
}

- (CIImage*) applyTo:(CIImage*)input {
    TRReplichromeTriX_extras* extras = [TRStylet preflightObjectForIdent:self.ident];
    if (!extras) {
        extras = [[TRReplichromeTriX_extras alloc] init];
        [TRStylet setPreflightObject:extras forIdent:self.ident];
    }
    TRCube* cube = [extras->cube copy];
    cube.inputImage = input;
    return cube.outputImage;
}
@end

