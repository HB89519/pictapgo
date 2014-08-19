#import "TRStylet.h"
#import "TRRecipe.h"
#import "TRNumberKnob.h"
#import "TRHelper.h"
#import "MemoryStatistics.h"
#import "CIContext+SingleThreadedRendering.h"

static int ddLogLevel = LOG_LEVEL_INFO;

@interface TRStylet_extras : NSObject {
@package
    NSArray* all;
    NSCache* preflightCache;
}
@end

static TRStylet_extras* extras;

@implementation TRStylet_extras
+ (TRStylet_extras*) manager {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        extras = [[super allocWithZone:NULL] init];
    });
    return extras;
}

+ (id) allocWithZone:(NSZone*)zone {
    return [self manager];
}

- (id) init {
    TRUNUSED CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();

    self = [super init];
    if (!self)
        return nil;

    preflightCache = [[NSCache alloc] init];

    if (wantDebugStyletList) {
        all = [NSArray arrayWithObjects:
          [[TRemptystylet alloc] init],
          //[[TRsimplebw alloc] init],
          //[[TRlabbw alloc] init],
          //[[TRlightson alloc] init],
          //[[TRlightsout alloc] init],
          //[[TRwarmitupkris alloc] init],
          //[[TRcoolasacucumber alloc] init],
          //[[TRcrispity alloc] init],
          //[[TRclaireify alloc] init],
          //[[TRezburn alloc] init],
          //[[TRequalize alloc] init],
          //[[TRlighten alloc] init],
          //[[TRdarken alloc] init],
          //[[TRhighlights alloc] init],
          //[[TRshadows alloc] init],
          [[TRautocolor alloc] init],
          [[TRautocontrast alloc] init],
          [[TRequalize alloc] init],
          [[TRbrooklynbw alloc] init],
          nil];
    } else {
        all = [NSArray arrayWithObjects:
          [[TRlightson alloc] init],
          [[TRlightsout alloc] init],
          [[TRautocontrast alloc] init],
          [[TRwarmitupkris alloc] init],
          [[TRcoolasacucumber alloc] init],
          [[TRautocolor alloc] init],
          [[TRgrainstorm alloc] init],
          [[TRpluscontrast alloc] init],
          [[TRequalize alloc] init],
          [[TRclaireify alloc] init],
          [[TRlofi alloc] init],
          [[TRvsco5 alloc] init],
          //[[TRohsnap alloc] init],
          [[TRfadedneutral alloc] init],
          [[TRfadedautumn alloc] init],
          [[TRfadedsummer alloc] init],
          [[TRezburn alloc] init],
          [[TRvanillakiss alloc] init],
          [[TRpistachio alloc] init],
          [[TRtdw alloc] init],
          [[TRsfh alloc] init],
          [[TRpoolparty alloc] init],
          [[TRorangeyouglad alloc] init],
          [[TRskinnyjeans alloc] init],
          //[[TRportland alloc] init],
          [[TRflirt alloc] init],
          [[TRtroy alloc] init],
          [[TRbullettooth alloc] init],
          [[TRoldglory alloc] init],
          [[TRsx70 alloc] init],

          [[TRflareupgolden alloc] init],
          [[TRmontecito alloc] init],
          [[TRsugarrush alloc] init],
          [[TRluxsoft alloc] init],
          [[TRgrandma alloc] init],
          [[TRcrispity alloc] init],

          [[TRsimplebw alloc] init],
          [[TRbrooklynbw alloc] init],
          [[TRdetroitbw alloc] init],
          [[TRbitchinbw alloc] init],
          [[TRmagicalbw alloc] init],
          [[TRoldskool alloc] init],
          [[TRgotham alloc] init],

          [[TRshadows alloc] init],
          [[TRhighlights alloc] init],
          [[TRvibrance alloc] init],
          [[TRdotscreen alloc] init],
          [[TRpc1 alloc] init],
          [[TRpc2 alloc] init],

          [[TRawake alloc] init],
          [[TReternal alloc] init],
          [[TRloft alloc] init],
          [[TRrandsburg alloc] init],
          [[TRterra alloc] init],
          [[TRair alloc] init],
          [[TRmason alloc] init],
          [[TRpowder alloc] init],

          [[TRfacebook alloc] init],
          [[TRinstagram alloc] init],
          [[TRezburn2 alloc] init],
          [[TRfadedwinter alloc] init],

          /*
          [[TRFlorabellaX alloc] initWithIdent:@"com.florabella.berry_wine"
            name:@"Berry Wine" group:@"Florabella" code:@"Flwn"],
          [[TRFlorabellaX alloc] initWithIdent:@"com.florabella.bw_vintage_film"
            name:@"BW Vintage Film" group:@"Florabella" code:@"Flbwg"],
          [[TRFlorabellaX alloc] initWithIdent:@"com.florabella.bw_vintage_film_2"
            name:@"BW Vintage Film 2" group:@"Florabella" code:@"Flbwb"],
          [[TRFlorabellaX alloc] initWithIdent:@"com.florabella.color_pop"
            name:@"Color Pop" group:@"Florabella" code:@"Flcp"],
          [[TRFlorabellaX alloc] initWithIdent:@"com.florabella.brandy"
            name:@"Brandy" group:@"Florabella" code:@"Flbr"],
          [[TRFlorabellaX alloc] initWithIdent:@"com.florabella.dramarama"
            name:@"Dramarama" group:@"Florabella" code:@"Fldr"],
          [[TRFlorabellaX alloc] initWithIdent:@"com.florabella.ocean_air"
            name:@"Ocean Air" group:@"Florabella" code:@"Flcn"],
          [[TRFlorabellaX alloc] initWithIdent:@"com.florabella.rosewood"
            name:@"Rosewood" group:@"Florabella" code:@"Flrw"],
          [[TRFlorabellaX alloc] initWithIdent:@"com.florabella.emulsion"
            name:@"Emulsion" group:@"Florabella" code:@"Flml"],
          */
          
          [[TRReplichrome400h alloc] init],
          [[TRReplichrome800z alloc] init],
          [[TRReplichromeAstia alloc] init],
          [[TRReplichromeEktar25 alloc] init],
          [[TRReplichromeVelvia50 alloc] init],
          [[TRReplichromePortra160NC alloc] init],
          [[TRReplichromeTMAX3200 alloc] init],
          [[TRReplichromeScala alloc] init],
          [[TRReplichromeTriX alloc] init],
          [[TRReplichromeAgfaPro200 alloc] init],
               
          nil];
    }

    if (YES) {
        NSArray* recipeList = [TRRecipe styletLibrary];
        NSSet* recipeListSet = [NSSet setWithArray:recipeList];
        NSMutableSet* allSet = [[NSMutableSet alloc] init];
        for (TRStylet* s in all)
            [allSet addObject:s.code];
        NSMutableSet* inRecipeButNotAll = [recipeListSet mutableCopy];
        [inRecipeButNotAll minusSet:allSet];
        NSMutableSet* inAllButNotRecipe = [allSet mutableCopy];
        [inAllButNotRecipe minusSet:recipeListSet];
        if (inRecipeButNotAll.count > 0) {
            DDLogWarn(@"!!!! in UI but not in stylets list: %@",
              [[inRecipeButNotAll allObjects] componentsJoinedByString:@" "]);
        }
        if (inAllButNotRecipe.count > 0) {
            DDLogWarn(@"!!!! in stylets list but not in UI: %@",
              [[inAllButNotRecipe allObjects] componentsJoinedByString:@" "]);
        }
    }

    if (LOG_INFO) {
        NSMutableString* codes = [[NSMutableString alloc] init];
        for (TRStylet* s in all)
            [codes appendFormat:@" %@", s.code];
        DDLogInfo(@"stylet list contains codes:%@", codes);
    }

    if (LOG_VERBOSE) {
        for (TRStylet* s in all)
            DDLogVerbose(@"    @\"%@\", @\"%@\",", s.name, s.code);
    }

    TRUNUSED CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    DDLogVerbose(@"TRStylet_extras init took %0.3f seconds", end - start);
    
    return self;
}
@end

@implementation TRStylet
@synthesize ident;
@synthesize name;
@synthesize group;
@synthesize knobs;
@synthesize masterSize;

- (id)copyWithZone:(NSZone *)zone {
    TRStylet* c = [[[self class] allocWithZone:zone] init];
    c->ident = self->ident;
    c->name = self->name;
    c->group = self->group;
    c->knobs = [[NSArray alloc] initWithArray:self->knobs copyItems:YES];
    c->masterSize = self->masterSize;
    return c;
}

+ (NSArray*) allAvailableStylets {
    return [TRStylet_extras manager]->all;
}

+ (void) purgeStyletPreflightCache {
    [[TRStylet_extras manager]->preflightCache removeAllObjects];
}

+ (void)setPreflightObject:(id)obj forIdent:(NSString*)ident {
    NSCache* cache = [TRStylet_extras manager]->preflightCache;
    [cache setObject:obj forKey:ident];
}

+ (id) preflightObjectForIdent:(NSString*)ident {
    NSCache* cache = [TRStylet_extras manager]->preflightCache;
    return [cache objectForKey:ident];
}

- (id) initWithIdent:(NSString*)theIdent name:(NSString*)theName
  group:(NSString*)theGroup code:(NSString*)theCode {
    self = [super init];
    if (self) {
        self.ident = theIdent;
        self.name = theName;
        self.group = theGroup;
        self.baseCode = theCode;
    }
    return self;
}

- (void)purgeCaches {
    // do nothing
}

- (CIImage*) applyTo:(CIImage*)input {
    [NSException raise:@"Base TRStylet:applyTo is not implemented"
      format:@"base method called"];
    return input;
}

static const BOOL wantThumbnailTimingLogs = NO;
static const BOOL wantLargeImageTimingLogs = NO;

- (CGImageRef) _applyToCGImage:(CGImageRef) CF_CONSUMED input CF_RETURNS_RETAINED {
    NSAssert(input, @"TRStylet \"%@\" _applyToCGImage input is nil", self.code);

    TRUNUSED CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    const CGSize inSize = CGSizeMake(CGImageGetWidth(input), CGImageGetHeight(input));
    TRUNUSED BOOL isThumb = inSize.width < 200 || inSize.height < 200;
    if ((wantLargeImageTimingLogs && !isThumb) ||
      (wantThumbnailTimingLogs && isThumb)) {
        DDLogInfo(@"starting stylet %@ (mem %@)", self.code, stringWithMemoryInfo());
    }

    CGImageRef output = nil;
    @autoreleasepool {
        CIImage* ciOutput = nil;
        @autoreleasepool {
            // 2013-07-01 15:00:33:905 PicTapGo[10279:4607] input retain count 0x23a05d90 3
            CIImage* ciInput = [CIImage imageWithCGImage:input];
            // 2013-07-01 15:00:33:905 PicTapGo[10279:4607] input retain count 0x23a05d90 4 (after imageWithCGImage)

            NSAssert(ciInput, @"TRStylet \"%@\" _applyToCGImage ciInput is nil", self.code);
            ciOutput = [self applyTo:ciInput];
            CGImageRelease(input);
            
            if (!ciOutput) {
                [DDLog flushLog];
                [NSException raise:@"PTGApplyStylet" format:@"failed to run stylet \"%@\"", self.code];
            }
        }

        CIContext* context = [TRHelper getCIContext];
        NSAssert(context, @"TRStylet \"%@\" _applyToCGImage context is nil", self.code);

        output = [context createCGImageMoreSafely:ciOutput fromRect:[ciOutput extent]];
        NSAssert(output, @"TRStylet \"%@\" _applyToCGImage output is nil", self.code);

        [TRHelper doneWithCIContext:context];
    }

    TRUNUSED CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    if ((wantLargeImageTimingLogs && !isThumb) ||
      (wantThumbnailTimingLogs && isThumb)) {
        DDLogInfo(@"finished stylet %@ (%.3f) (mem %@)",
          self.code, end - start, stringWithMemoryInfo());
    }

    NSAssert(output, @"TRStylet \"%@\" _applyToCGImage result is nil", self.code);
    return output;
}

- (CGImageRef)applyStyletToCGImage:(CGImageRef) CF_CONSUMED input CF_RETURNS_RETAINED {
    @autoreleasepool {
        return [self _applyToCGImage:input];
    }
}

- (TRNumberKnob*) strengthKnob {
    return [self knobIdentifiedBy:@"strength"];
}

- (NSNumber*) strength {
    return self.strengthKnob.value;
}

- (void) setStrength:(NSNumber*)strength {
    for (TRNumberKnob* k in knobs)
        if ([k.ident isEqual:@"strength"])
            k.value = strength;
}

- (void) setKnob:(NSString *)theIdent value:(float)value {
    [self knobIdentifiedBy:theIdent].value = [NSNumber numberWithFloat:value];
}

- (NSNumber*) valueForKnob:(NSString*)theIdent {
    return [[self knobIdentifiedBy:theIdent] actualValue];
}

- (NSNumber*) actualStrength {
    return [self strengthKnob].actualValue;
}

- (TRNumberKnob*) knobIdentifiedBy:(NSString*)theIdent {
    for (TRNumberKnob* k in knobs)
        if ([k.ident isEqualToString:theIdent])
            return k;
    return nil;
}

- (CGImageRef) strengthBaseImage:(CGImageRef)originalImage
  CF_RETURNS_RETAINED
{
    return CGImageRetain(originalImage);
}

- (NSString*) codeWithSpecificStrength:(NSNumber*)strength {
    NSInteger str = strength.integerValue;
    if ([TRStylet isEmptyStylet:self] || str <= 1)
        return @"";
    if (str > 99)
        return self.baseCode;

    NSMutableString* c = [[NSMutableString alloc] init];
    [c appendString:self.baseCode];
    if (str >= 10 && str % 10 == 0) {
        [c appendFormat:@"%zd", str / 10];
    } else {
        [c appendFormat:@"%02zd", str];
    }

    return c;
}

- (NSString*) code {
    return [self codeWithSpecificStrength:self.strength];
}

+ (TRStylet*) emptyStylet {
    return [[TRemptystylet alloc] init];
}

+ (TRStylet*) styletIdentifiedBy:(NSString*)ident {
    if (!ident || [ident isEqualToString:EMPTY_STYLET_IDENT])
        return [TRStylet emptyStylet];
    for (TRStylet* s in [self allAvailableStylets]) {
        if ([s.ident isEqualToString:ident])
            return s;
    }
    NSAssert(NO, @"Couldn't find Stylet with ident %@", ident);
    return nil;
}

+ (TRStylet*) styletIdentifiedByCode:(NSString*)code {
    if (!code || [code isEqualToString:@""])
        return [TRStylet emptyStylet];
    for (TRStylet* s in [self allAvailableStylets]) {
        if ([s.baseCode isEqualToString:code])
            return s;
    }
    //NSAssert1(NO, @"Couldn't find Stylet with code %@", code);
    return nil;
}

+ (BOOL) isEmptyStylet:(TRStylet*)stylet {
    return [stylet.ident isEqualToString:EMPTY_STYLET_IDENT];
}
@end

@implementation TRStyletBW
- (CGImageRef) strengthBaseImage:(CGImageRef)originalImage CF_RETURNS_RETAINED {
    TRsimplebw* bw = [[TRsimplebw alloc] init];
    CGImageRef img = [bw applyStyletToCGImage:originalImage];
    return img;
}
@end

