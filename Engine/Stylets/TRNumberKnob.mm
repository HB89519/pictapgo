#import "TRFilter.h"
#import "TRNumberKnob.h"

static int ddLogLevel = LOG_LEVEL_INFO;

// Internal API for TRNumberKnob
@interface TRNumberKnob ()
@property (readwrite) NSString* ident;
@property (readwrite) NSString* name;
@property (readwrite) NSNumber* minimum;
@property (readwrite) NSNumber* maximum;
@property (readwrite, copy) NSNumber* actualMin;
@property (readwrite, copy) NSNumber* actualMax;
@property (readonly) NSNumber* actualValue;
@end

@implementation TRNumberKnob
@synthesize ident;
@synthesize name;
@synthesize value;
@synthesize minimum;
@synthesize maximum;
@synthesize actualMin;
@synthesize actualMax;

- (id) copyWithZone:(NSZone *)zone {
    TRNumberKnob* c = [[TRNumberKnob allocWithZone:zone] init];
    c->ident = self->ident;
    c->name = self->name;
    c->value = [self->value copyWithZone:zone];
    c->minimum = self->minimum;
    c->maximum = self->maximum;
    c->actualMin = self->actualMin;
    c->actualMax = self->actualMax;
    return c;
}

+ (TRNumberKnob*) newKnobIdentifiedBy:(NSString*)ident named:(NSString*)name
  value:(float)val uiMin:(float)uiMin uiMax:(float)uiMax
  actualMin:(float)actualMin actualMax:(float)actualMax {
    NSAssert(uiMin < uiMax, @"%f < %f", uiMin, uiMax);
    NSAssert(actualMin < actualMax, @"%f < %f", actualMin, actualMax);
    TRNumberKnob* k = [[TRNumberKnob alloc] init];
    k.ident = ident;
    k.name = name;
    k.minimum = [NSNumber numberWithFloat:uiMin];
    k.maximum = [NSNumber numberWithFloat:uiMax];
    k.value = [NSNumber numberWithFloat:val];
    k.actualMin = [NSNumber numberWithFloat:actualMin];
    k.actualMax = [NSNumber numberWithFloat:actualMax];
    return k;
}

- (NSNumber*) actualValue {
    const float uiRange = [maximum floatValue] - [minimum floatValue];
    const float uiDelta = [value floatValue] - [minimum floatValue];
    const float uiFraction = uiDelta / uiRange;
    const float actualRange = [actualMax floatValue] - [actualMin floatValue];
    const float actualFraction = actualRange * uiFraction;
    const float val = [actualMin floatValue] + actualFraction;
    DDLogVerbose(@"%@ actualValue %f for %@ (%@ %@ %@ %@)",
      ident, val, value, minimum, maximum, actualMin, actualMax);
    return [NSNumber numberWithFloat:val];
}

- (NSNumber*) value {
    return self->value;
}

- (void) setValue:(NSNumber *)val {
    NSAssert(val, @"nil value");
    NSAssert([val compare:self->minimum] >= 0, @"%@ < %@", val, minimum);
    NSAssert([val compare:self->maximum] <= 0, @"%@ > %@", val, maximum);
    self->value = val;
}

@end

