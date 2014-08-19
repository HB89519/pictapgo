#import "TRFilter.h"
#include <iostream>

static int ddLogLevel = LOG_LEVEL_INFO;

using tr::util::Spline;

@implementation TRLevels
@synthesize inputImage;
@synthesize inputLevels;
@synthesize inputStrength;

static float lerp(float v1, float v2, float strength) {
    return v1 + (v2 - v1) * strength;
}

std::ostream& operator<<(std::ostream& s, const LevelsAdjustments::Adjustment& a) {
    return s << a.inMin << "," << a.inMax << ":" << a.outMin << "," << a.outMax
      << ":" << a.gamma;
}

std::ostream& operator<<(std::ostream& s, const LevelsAdjustments& adj) {
    return s << "R:" << adj.adj[0] << " G:" << adj.adj[1] << " B:" << adj.adj[2]
      << " C:" << adj.adj[3];
}

static float level(const LevelsAdjustments::Adjustment& a, float v) {
    const float inMin = a.inMin / 255.0;
    const float inMax = a.inMax / 255.0;
    const float outMin = a.outMin / 255.0;
    const float outMax = a.outMax / 255.0;
    if (v <= inMin)
        return outMin;
    if (v >= inMax)
        return outMax;
    return outMin + (outMax - outMin) * powf(v / (inMax - inMin), 1.0f / a.gamma);
}

static NSData* cube(size_t dimension, float strength,
  const LevelsAdjustments& adj)
{
    DDLogCVerbose(@"TRLevels cube strength %f", strength);
    //std::cout << adj << "\n";

    const size_t size = dimension;
    const size_t cubeDataSize = size * size * size * sizeof(float) * 4;
    float* cubeData = (float*)malloc(cubeDataSize);

    float* p = cubeData;
    float cv[4] = {0.0, 0.0, 0.0, 1.0};
    for (size_t b = 0; b < size; ++b) {
        cv[2] = lerp(float(b) / float(size - 1),
          level(adj.adj[3], level(adj.adj[2], float(b) / float(size - 1))),
          strength);
        for (size_t g = 0; g < size; ++g) {
            cv[1] = lerp(float(g) / float(size - 1),
              level(adj.adj[3], level(adj.adj[1], float(g) / float(size - 1))),
              strength);
            for (size_t r = 0; r < size; ++r) {
                cv[0] = lerp(float(r) / float(size - 1),
                  level(adj.adj[3], level(adj.adj[0], float(r) / float(size - 1))),
                  strength);
                
                p[0] = cv[0], p[1] = cv[1], p[2] = cv[2], p[3] = cv[3];
                p += 4;
            }
        }
    }

    NSData* data = [NSData dataWithBytesNoCopy:cubeData length:cubeDataSize
      freeWhenDone:YES];
    NSCAssert(data, @"TRLevels cube data is nil");
    return data;
}

+ (TRLevels*) newWithInput:(CIImage*)inputImage
  levels:(const LevelsAdjustments&)levels strength:(NSNumber*)strength
{
    TRLevels* l = [[TRLevels alloc] init];
    NSAssert(l, @"TRLevels newWithInput l is nil");
    l.inputImage = inputImage;
    l.inputLevels = levels;
    l.inputStrength = strength;
    
    l->colorCubeSize = 8;
    l->colorCube = cube(l->colorCubeSize, 1.0, l.inputLevels);
    
    return l;
}

+ (TRLevels*) newWithInput:(CIImage*)inputImage
  levels:(const LevelsAdjustments&)levels
{
    return [TRLevels newWithInput:inputImage levels:levels
      strength:[NSNumber numberWithFloat:1]];
}

-(id)copyWithZone:(NSZone *)zone {
  TRLevels *another = [[TRLevels allocWithZone:zone] init];
  another->inputImage = nil;
  another->inputLevels = inputLevels;
  another->inputStrength = [inputStrength copyWithZone:zone];
  another->colorCubeSize = colorCubeSize;
  another->colorCube = [colorCube copyWithZone:zone];

  return another;
}

- (void) setStrength:(NSNumber*)s {
    inputStrength = s;
}

- (CIImage*) outputImage {
    DDLogVerbose(@"TRLevels outputImage");
    
    NSAssert(self->colorCube, @"TRLevels colorCube is nil");
    NSAssert([self->colorCube isKindOfClass:[NSData class]], @"TRLevels colorCube is not NSData!");

    const float strength = [inputStrength floatValue];
    if (strength < 0.01) {
        DDLogVerbose(@"TRLevels strength %f is a no-op", strength);
        return inputImage;
    }
    
    /*
    static const int size = 8;
    NSData* cubeData = cube(size, strength, inputLevels);
    */
    
    CIFilter* cube = [CIFilter filterWithName:@"CIColorCube"];
    NSAssert(cube, @"TRLevels outputImage cube is nil");
    [cube setDefaults];
    [cube setValue:inputImage forKey:@"inputImage"];
    [cube setValue:self->colorCube forKey:@"inputCubeData"];
    [cube setValue:[NSNumber numberWithLong:self->colorCubeSize]
      forKey:@"inputCubeDimension"];

    CIImage* result = cube.outputImage;
    NSAssert(result, @"TRLevels outputImage result is nil");
    return result;
}

- (void)setNilValueForKey:(NSString*)key {
    DDLogVerbose(@"TRLevels setNilValueForKey %@", key);
    if ([key isEqualToString:@"inputLevels"]) {
    } else {
        [super setNilValueForKey:key];
    }
}

@end
