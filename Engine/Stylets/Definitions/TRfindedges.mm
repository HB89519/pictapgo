#if 0

#import "TRStylet.h"

@implementation TRfindedges
- (id) init {
    self = [super initWithIdent:@"com.gettotallyrad.findedges"
      name:@"Find Edges" group:@"Basics" code:@"#"];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1],
          nil];
    }
    return self;
}
- (CIImage*) applyTo:(CIImage*)input {
    TRFindEdges* fe = [TRFindEdges newWithInput:input];
    return fe.outputImage;
}
@end

#endif