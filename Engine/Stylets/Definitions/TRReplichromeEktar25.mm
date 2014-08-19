#import "TRStylet.h"

static int ddLogLevel = LOG_LEVEL_INFO;

@interface TRReplichromeEktar25_extras : NSObject {
@package
    TRCube* cube;
}
@end

@implementation TRReplichromeEktar25_extras
- (id) init {
    TRUNUSED CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    cube = [TRCube newWithInput:nil cubeFile:@"cube-replichrome-ektar25" size:16];
    TRUNUSED CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    DDLogVerbose(@"TRReplichromeEktar25_extras init took %0.3f seconds", end - start);

    return self;
}
- (id) copyWithZone:(NSZone*)zone {
    return self;
}
@end

@implementation TRReplichromeEktar25
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.replichrome-ektar25"
      name:@"Ektar 25" group:@"Clones" code:@"Xrd"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Effect Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1],
          nil];
    }
    return self;
}

- (CIImage*) applyTo:(CIImage*)input {
    TRReplichromeEktar25_extras* extras = [TRStylet preflightObjectForIdent:self.ident];
    if (!extras) {
        extras = [[TRReplichromeEktar25_extras alloc] init];
        [TRStylet setPreflightObject:extras forIdent:self.ident];
    }
    TRCube* cube = [extras->cube copy];
    cube.inputImage = input;
    return cube.outputImage;
}
@end

