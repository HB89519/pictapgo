#import "TRStylet.h"

static int ddLogLevel = LOG_LEVEL_INFO;

@interface TRReplichromeAgfaPro200_extras : NSObject {
@package
    TRCube* cube;
}
@end

@implementation TRReplichromeAgfaPro200_extras
- (id) init {
    TRUNUSED CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    cube = [TRCube newWithInput:nil cubeFile:@"cube-replichrome-agfapro200" size:16];
    TRUNUSED CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    DDLogVerbose(@"TRReplichromeAgfaPro200_extras init took %0.3f seconds", end - start);

    return self;
}
- (id) copyWithZone:(NSZone*)zone {
    return self;
}
@end

@implementation TRReplichromeAgfaPro200
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.replichrome-agfapro200"
      name:@"Agfa Pro 200" group:@"Clones" code:@"Xrj"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Effect Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1],
          nil];
    }
    return self;
}

- (CIImage*) applyTo:(CIImage*)input {
    TRReplichromeAgfaPro200_extras* extras = [TRStylet preflightObjectForIdent:self.ident];
    if (!extras) {
        extras = [[TRReplichromeAgfaPro200_extras alloc] init];
        [TRStylet setPreflightObject:extras forIdent:self.ident];
    }
    TRCube* cube = [extras->cube copy];
    cube.inputImage = input;
    return cube.outputImage;
}
@end

