#import "TRRecipe.h"
#import "TRFilter.h"
#import "TRNumberKnob.h"

#define EMPTY_STYLET_IDENT @"com.gettotallyrad.empty"

// Describes a Stylet and that Stylet's knobs
@interface TRStylet: NSObject <NSCopying>
@property (readonly) NSString* code;

// Shortcut methods to tweak a Stylet's strength
@property (copy) NSNumber* strength;

- (NSString*) codeWithSpecificStrength:(NSNumber*)strength;

+ (id) preflightObjectForIdent:(NSString*)ident;
+ (void) setPreflightObject:(id)obj forIdent:(NSString*)ident;
+ (void) purgeStyletPreflightCache;

+ (TRStylet*) emptyStylet;
+ (BOOL) isEmptyStylet:(TRStylet*)stylet;
+ (TRStylet*) styletIdentifiedBy:(NSString*)ident;
+ (TRStylet*) styletIdentifiedByCode:(NSString*)code;

- (id) initWithIdent:(NSString*)ident name:(NSString*)name
  group:(NSString*)group code:(NSString*)code;
- (CIImage*) applyTo:(CIImage*)input;
- (CGImageRef) applyStyletToCGImage:(CGImageRef) CF_CONSUMED input CF_RETURNS_RETAINED;
- (TRNumberKnob*) knobIdentifiedBy:(NSString*)ident;
- (void) setKnob:(NSString*)ident value:(float)value;
- (NSNumber*) valueForKnob:(NSString*)ident;
- (NSNumber*) actualStrength;
- (CGImageRef) strengthBaseImage:(CGImageRef)originalImage CF_RETURNS_RETAINED;

@property (readonly) TRNumberKnob* strengthKnob;
@property (readwrite) NSString* ident;
@property (readwrite) NSString* name;
@property (readwrite) NSString* group;
@property (readwrite) NSString* baseCode;
@property (readwrite, copy) NSArray* knobs;
@property (readwrite) CGSize masterSize;
@end

@interface TRStyletBW : TRStylet
- (CGImageRef) strengthBaseImage:(CGImageRef)originalImage CF_RETURNS_RETAINED;
@end

@interface TRemptystylet : TRStylet
@end

@interface TRgaussianblur : TRStylet
@end

@interface TRhighpass : TRStylet
@end

@interface TRautocolor : TRStylet
@end

@interface TRautocontrast : TRStylet
@end

@interface TRequalize : TRStylet
@end

//@interface TRfindedges : TRStylet
//@end

@interface TRboxblur : TRStylet
@end

@interface TRsepia : TRStylet
@end

@interface TRlightson : TRStylet
@end

@interface TRlightsout : TRStylet
@end

@interface TRlighten : TRStylet
@end

@interface TRdarken : TRStylet
@end

@interface TRlabbw : TRStylet
@end

@interface TRsimplebw : TRStylet
// NB: This is NOT derived from TRStyletBW.  It is used as the "strength
// basis" filter for other stylets that ARE derived from TRStyletBW.
@end

@interface TRpluscontrast : TRStylet
@end

/*
@interface TRpluscontrast2 : TRStylet
@end
*/

@interface TRsugarrush : TRStylet
@end

@interface TRluxsoft : TRStylet
@end

@interface TRwarmitupkris : TRStylet
@end

@interface TRcoolasacucumber : TRStylet
@end

@interface TRfadedneutral : TRStylet
@end

@interface TRflareupgolden : TRStylet
@end

@interface TRskinnyjeans : TRStylet
@end

@interface TRpistachio : TRStylet
@end

@interface TRtdw : TRStylet
@end

@interface TRsfh : TRStylet
@end

@interface TRpoolparty : TRStylet
@end

@interface TRmontecito : TRStylet
@end

@interface TRorangeyouglad : TRStylet
@end

@interface TRflirt : TRStylet
@end

@interface TRmagicalbw : TRStyletBW
@end

@interface TRtroy : TRStylet
@end

@interface TRdetroitbw : TRStyletBW
@end

@interface TRbullettooth : TRStylet
@end

@interface TRohsnap : TRStylet
@end

@interface TRfadedautumn : TRStylet
@end

@interface TRfadedspring : TRStylet
@end

@interface TRfadedsummer : TRStylet
@end

@interface TRfadedwinter : TRStylet
@end

@interface TRgrainstorm : TRStylet
@end

@interface TRezburn : TRStylet
@end

@interface TRezburn2 : TRStylet
@end

@interface TRbitchinbw : TRStyletBW
@end

@interface TRoldskool : TRStyletBW
@end

@interface TRgrandma : TRStylet
@end

@interface TRclaireify : TRStylet
@end

@interface TRvanillakiss : TRStylet
@end

@interface TRgotham : TRStyletBW
@end

@interface TRlofi : TRStylet
@end

@interface TRvsco5 : TRStylet
@end

@interface TRawake : TRStylet
@end

@interface TRcrispity : TRStylet
@end

@interface TRportland : TRStylet
@end

@interface TRshadows : TRStylet
@end

@interface TRhighlights : TRStylet
@end

@interface TRvibrance : TRStylet
@end

@interface TRdotscreen : TRStylet
@end

@interface TRpc1 : TRStylet
@end

@interface TRpc2 : TRStylet
@end

@interface TRbrooklynbw : TRStyletBW
@end

@interface TRoldglory : TRStylet
@end

@interface TRsx70 : TRStylet
@end

@interface TReternal : TRStylet
@end

@interface TRterra : TRStylet
@end

@interface TRrandsburg : TRStylet
@end

@interface TRloft : TRStylet
@end

@interface TRair : TRStylet
@end

@interface TRmason : TRStylet
@end

@interface TRpowder : TRStylet
@end

@interface TRfacebook : TRStylet
@end

@interface TRinstagram : TRStylet
@end

@interface TRFlorabellaX : TRStylet
- (id)initWithIdent:(NSString*)ident name:(NSString*)name group:(NSString*)group code:(NSString*)code;
@end

@interface TRReplichrome400h : TRStylet
@end

@interface TRReplichrome800z : TRStylet
@end

@interface TRReplichromeAstia : TRStylet
@end

@interface TRReplichromeEktar25 : TRStylet
@end

@interface TRReplichromeVelvia50 : TRStylet
@end

@interface TRReplichromePortra160NC : TRStylet
@end

@interface TRReplichromeTMAX3200 : TRStylet
@end

@interface TRReplichromeScala : TRStylet
@end

@interface TRReplichromeTriX : TRStylet
@end

@interface TRReplichromeAgfaPro200 : TRStylet
@end
