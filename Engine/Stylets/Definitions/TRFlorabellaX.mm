#import "TRStylet.h"

static int ddLogLevel = LOG_LEVEL_INFO;

@interface TRFlorabellaX_extras : NSObject
@property NSMutableDictionary* cubes;
@end

static TRFlorabellaX_extras* extras;

@implementation TRFlorabellaX_extras
+ (TRFlorabellaX_extras*) extrasManager {
    if (!extras)
        extras = [[super allocWithZone:NULL] init];
    return extras;
}
+ (id) allocWithZone:(NSZone*)zone {
    return [self extrasManager];
}
- (void)addCubeNamed:(NSString*)name {
    NSString* ident = [NSString stringWithFormat:@"com.florabella.%@", name];
    NSString* filename = [@"Florabella Colorplay LUTs" stringByAppendingPathComponent:name];
    TRCube* cube = [TRCube newWithInput:nil cubeFile:filename size:16];
    [self.cubes setObject:cube forKey:ident];
}
- (id) init {
    self = [super init];

    TRUNUSED CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    self.cubes = [[NSMutableDictionary alloc] init];

    NSArray* names = [NSArray arrayWithObjects:
      @"1975",
      @"alabaster",
      @"antique_pink",
      @"berry_wine",
      @"brandy",
      @"brownish",
      @"buttercream",
      @"bw_vintage_film",
      @"bw_vintage_film_2",
      @"color_pop",
      @"dramarama",
      @"earth",
      @"emulsion",
      @"ethereal",
      @"flowerchild",
      @"french_blue",
      @"ginger",
      @"hazy_haze",
      @"lola",
      @"marigold",
      @"ocean_air",
      @"organic",
      @"peace",
      @"pink_honey",
      @"rosewood",
      @"sophie",
      @"sorbet",
      @"summer_peach",
      @"sweet_lilac",
      @"wildheart",
      @"winter",
      nil];

    for (NSString* name in names)
        [self addCubeNamed:name];

    TRUNUSED CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    DDLogVerbose(@"TRFlorabellaX_extras init took %0.3f seconds", end - start);

    return self;
}
- (id) copyWithZone:(NSZone*)zone {
    return self;
}
@end

@interface TRFlorabellaX ()
@property NSString* cubeName;
@end

@implementation TRFlorabellaX
- (id) initWithIdent:(NSString*)ident name:(NSString*)name group:(NSString*)group code:(NSString*)code {
    [TRFlorabellaX_extras extrasManager];
    self = [super initWithIdent:ident name:name group:group code:code];
    if (self) {
        self.knobs = [NSArray arrayWithObjects:
          [TRNumberKnob newKnobIdentifiedBy:@"strength" named:@"Effect Strength"
            value:100 uiMin:0 uiMax:100 actualMin:0 actualMax:1],
          nil];
        self.cubeName = ident;
    }
    return self;
}

- (CIImage*) applyTo:(CIImage*)input {
    TRCube* cube = [[[TRFlorabellaX_extras extrasManager].cubes valueForKey:self.cubeName] copy];
    NSAssert(cube, @"TRFlorabellaX applyTo cube %@ is nil", self.cubeName);
    cube.inputImage = input;
    return cube.outputImage;
}
@end
