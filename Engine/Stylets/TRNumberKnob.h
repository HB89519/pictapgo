// Encapsulates a "tweakable" Stylet knob
@interface TRNumberKnob: NSObject <NSCopying>
@property (readonly) NSString* ident;
@property (readonly) NSString* name;
@property (copy) NSNumber* value;
@property (readonly) NSNumber* minimum;
@property (readonly) NSNumber* maximum;
@end

@interface TRNumberKnob ()

+ (TRNumberKnob*) newKnobIdentifiedBy:(NSString*)ident named:(NSString*)name
  value:(float)val uiMin:(float)uiMin uiMax:(float)uiMax
  actualMin:(float)actualMin actualMax:(float)actualMax;

- (NSNumber*) actualValue;

@end