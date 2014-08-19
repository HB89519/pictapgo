#import <Foundation/NSException.h>
#import "TRRecipe.h"
#import "TRFilter.h"
#import "TRHelper.h"
#import "TRNumberKnob.h"
#import "TRStylet.h"
#import "Spline.hpp"
#import "TRStatistics.h"
#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/UTCoreTypes.h>

static int ddLogLevel = LOG_LEVEL_INFO;

using tr::util::Spline;

@interface TRRecipeCodeTokenizer () {
    NSData* buf;
    const unsigned char* pos;
    const unsigned char* end;
}
@end

@implementation TRRecipeCodeTokenizer
- (TRRecipeCodeTokenizer*) initWithCode:(NSString*)code {
    self = [super init];
    if (self) {
        buf = [code dataUsingEncoding:NSUTF8StringEncoding];
        pos = (const unsigned char*)[buf bytes];
        end = pos + [buf length];
    }
    return self;
}

- (id) next {
    if (pos == end)
        return nil;

    if (strchr("()[]:", *pos)) {
        return [[NSString alloc] initWithBytes:pos++ length:1 encoding:NSUTF8StringEncoding];
    }

    if (isupper(*pos)) {
        const unsigned char* p = pos;
        ++p;
        while (p != end && islower(*p))
            ++p;
        NSString* result = [[NSString alloc] initWithBytes:pos length:p - pos encoding:NSUTF8StringEncoding];
        pos = p;
        return result;
    }

    if (isnumber(*pos)) {
        const unsigned char* p = pos;
        ++p;
        while (p != end && isnumber(*p))
            ++p;
        if (p - pos > 2)
            [NSException raise:@"RecipeParseError" format:@"unexpectedly long strength in \"%@\"",
              [[NSString alloc] initWithData:buf encoding:NSUTF8StringEncoding]];
        NSNumber* result = nil;
        if (p - pos == 1) {
            result = [NSNumber numberWithInt:(*pos - '0') * 10];
        } else if (*pos == '0') {
            result = [NSNumber numberWithInt:(*pos - '0')];
        } else {
            result = [NSNumber numberWithInt:(*pos - '0') * 10 + (*(pos + 1) - '0')];
        }
        pos = p;
        return result;
    }

    [NSException raise:@"RecipeParseError" format:@"couldn't tokenize \"%s\"", buf.bytes];
    return nil;
}
@end

@interface TRRecipeInstruction : NSObject
@property id element;
@property NSUInteger strength;
@end

@implementation TRRecipeInstruction
@end

@protocol TRRecipeNodeVisitor;

@interface TRRecipeNode()
@property id element;
@property NSUInteger strength;
- (void) visitWithVisitor:(id<TRRecipeNodeVisitor>)visitor;
@end

@protocol TRRecipeNodeVisitor <NSObject>
- (void) visitAtom:(TRRecipeNode*)node;
- (void) enterRecipe:(TRRecipeNode*)node;
- (void) leaveRecipe:(TRRecipeNode*)node;
- (void) enterBranch:(TRRecipeNode*)node;
- (void) leaveBranch:(TRRecipeNode*)node;
@end

@implementation TRRecipeNode
@synthesize element = _element;

- (id) init {
    self = [super init];
    if (self) {
        _strength = 100;
    }
    return self;
}
- (NSString*)description {
    return [self descriptionWithDepth:0];
}

- (NSString*)descriptionWithDepth:(NSUInteger)depth {
    NSMutableString* result = [[NSMutableString alloc] init];
    if ([self.element isKindOfClass:NSArray.class]) {
        if (self.strength < 100)
            [result appendString:@"("];
        for (id i in self.element) {
            [result appendString:[i descriptionWithDepth:depth + 1]];
        }
        if (self.strength < 100)
            [result appendString:@")"];
    } else {
        [result appendString:[self.element description]];
    }
    if (self.strength == 100) {
    } else if (self.strength % 10 == 0) {
        [result appendFormat:@"%zd", self.strength / 10];
    } else {
        [result appendFormat:@"%02zd", self.strength];
    }
    return result;
}
- (id)element {
    return _element;
}
- (void)setElement:(id)element {
    NSAssert(element != self, @"TRRecipeNode setElement attempted to add loop in graph");
    _element = element;
}

- (void)visitWithVisitor:(id<TRRecipeNodeVisitor>)visitor {
    if ([self.element isKindOfClass:NSArray.class]) {
        [visitor enterRecipe:self];
        for (id i in self.element) {
            [i visitWithVisitor:visitor];
        }
        [visitor leaveRecipe:self];
    } else {
        [visitor visitAtom:self];
    }
}

- (void) hoistInto:(NSMutableArray*)a {
    if ([_element isKindOfClass:[NSArray class]])
        [a addObjectsFromArray:_element];
    else
        [a addObject:self];
}

- (void) normalize {
    if ([_element isKindOfClass:[NSArray class]]) {
        NSMutableArray* a = [[NSMutableArray alloc] init];
        for (TRRecipeNode* n in (NSArray*)_element) {
            [n normalize];
            if (n.strength >= 98.0) {
                [n hoistInto:a];
            } else if (n.strength <= 2.0) {
                // do nothing
            } else {
                [a addObject:n];
            }
        }
        _element = a;
    }
}
@end

@interface TRRecipeCodeParser()
@property NSString* code;
@property TRRecipeCodeTokenizer* tok;
@property TRRecipeNode* tree;
@end

@implementation TRRecipeCodeParser
- (TRRecipeCodeParser*) initWithCode:(NSString*)code {
    self = [super init];
    if (self) {
        @autoreleasepool {
            _code = code;
            _tok = [[TRRecipeCodeTokenizer alloc] initWithCode:code];
            _tree = [self parseTree];
            /*
            TRRecipeDumper* d = [[TRRecipeDumper alloc] initWithTree:_tree];
            DDLogVerbose(@"code %@ parsed as %@", _code, d.description);
            */
        }
    }
    return self;
}
- (TRRecipeNode*) branch {
    [NSException raise:@"RecipeParseError" format:@"unimplemented"];
    return nil;
}

- (TRRecipeNode*) parseTree {
    TRRecipeNode* node = [[TRRecipeNode alloc] init];
    NSMutableArray* a = [[NSMutableArray alloc] init];
    node.element = a;

    id t;
    while ((t = self.tok.next) != nil) {
        if ([t isKindOfClass:NSString.class]) {
            if ([t isEqual:@"("]) {
                [a addObject:[self parseTree]];
            } else if ([t isEqual:@")"]) {
                break;
            } else if ([t isEqual:@"["]) {
                [a addObject:[self branch]];
            } else if ([t isEqual:@":"] || [t isEqual:@"]"]) {
                [NSException raise:@"RecipeParseError" format:@"unexpected token %@", t];
            } else {
                TRRecipeNode* n = [[TRRecipeNode alloc] init];
                n.element = t;
                [a addObject:n];
            }
        } else if ([t isKindOfClass:NSNumber.class]) {
            TRRecipeNode* n = [a lastObject];
            n.strength = [(NSNumber*)t integerValue];
        } else {
            [NSException raise:@"RecipeParseError" format:@"unexpected recipe token type %@", t];
        }
    }

    return node;
}

@end

// ----------------------------------------------------------------------

@interface ImageHandle : NSObject {
    CGImageRef temporary;
    NSURL* temporaryFileURL;
}
@property (atomic) CGImageRef image;
@end

@implementation ImageHandle
@synthesize image = _image;
- (id)initWithImage:(CGImageRef)image {
    self = [super init];
    if (self) {
        _image = CGImageRetain(image);
    }
    return self;
}
- (void)dealloc {
    if (_image)
        CGImageRelease(_image);
    if (temporary)
        CGImageRelease(temporary);
}
- (CGImageRef)image {
    return _image;
}
- (void)setImage:(CGImageRef)image {
    CGImageRef tmp = _image;
    _image = CGImageRetain(image);
    CGImageRelease(tmp);
}
- (void)releaseWithoutSavingToTemporaryFile {
    NSAssert(temporary == nil, @"ImageHandle expected temporary to be nil, but temporary=%p _image=%p",
      temporary, _image);
    CGImageRef tmp = _image;
    _image = nil;
    CGImageRelease(tmp);
}
- (void)releaseAfterSavingToTemporaryFile:(NSString*)folder isLarge:(BOOL)isLarge {
    temporary = CGImageRetain(_image);
    CGImageRelease(_image);
    _image = nil;

    if (isLarge) {
        TRUNUSED CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();

        NSUUID* uuid = [[NSUUID alloc] init];
        NSString* tempFile = [[folder stringByAppendingPathComponent:[uuid UUIDString]]
          stringByAppendingPathExtension:@"jpg"];
        temporaryFileURL = [NSURL fileURLWithPath:tempFile];

        DDLogVerbose(@"saving %@", temporaryFileURL);
        @autoreleasepool {
            NSData* imageData = nil;
            @autoreleasepool {
                UIImage* uimg = [UIImage imageWithCGImage:temporary];
                imageData = UIImageJPEGRepresentation(uimg, 0.99);
            }
            [imageData writeToFile:[temporaryFileURL path] atomically:YES];
        }

        TRUNUSED CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
        DDLogInfo(@"saving %@ took %.3f", temporaryFileURL, end - start);

        CGImageRef tmp = temporary;
        temporary = nil;
        CGImageRelease(tmp);
    }
}

- (void)restoreFromTemporaryFileAndRetain {
    if (temporaryFileURL) {
        @autoreleasepool {
            TRUNUSED CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
            DDLogVerbose(@"restoring %@", temporaryFileURL);

            CGDataProviderRef provider = CGDataProviderCreateWithURL((__bridge CFURLRef)temporaryFileURL);
            temporary = CGImageCreateWithJPEGDataProvider(provider, NULL, NO, kCGRenderingIntentDefault);
            CFRelease(provider);

            TRUNUSED CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
            DDLogInfo(@"restoring %@ (%ldx%ld) took %.3f", temporaryFileURL,
              CGImageGetWidth(temporary), CGImageGetHeight(temporary), end - start);

            NSError* err = nil;
            BOOL res = [[NSFileManager defaultManager] removeItemAtURL:temporaryFileURL error:&err];
            if (!res && err)
                DDLogWarn(@"failed to remove temporary file %@: %@", temporaryFileURL, err);
            temporaryFileURL = nil;
        }
    }

    _image = CGImageRetain(temporary);
    CGImageRelease(temporary);
    temporary = nil;
}

- (NSString*)description {
    return [NSString stringWithFormat:@"ImageHandle %p img=%p (%ld) temp=%p %@", self,
      _image, _image ? CFGetRetainCount(_image) : 0, temporary, temporaryFileURL];
}
@end

// ----------------------------------------------------------------------

@interface TRRecipeRunner : NSObject <TRRecipeNodeVisitor> {
    CGSize masterSize;
    NSMutableArray* stack;
    BOOL isLarge;
    NSString* tempFolder;
}
@end

@implementation TRRecipeRunner
- (id) initWithMasterSize:(CGSize)size isLarge:(BOOL)lg {
    self = [super init];
    if (self) {
        masterSize = size;
        isLarge = lg;
        stack = [[NSMutableArray alloc] init];
        if (isLarge) {
            NSString* tempPath = NSTemporaryDirectory();
            tempFolder = [tempPath stringByAppendingPathComponent:@"recipe-running"];

            NSFileManager* fm = [NSFileManager defaultManager];
            BOOL exists = [fm fileExistsAtPath:tempFolder];
            DDLogVerbose(@"tempFolder %@ exists=%d", tempFolder, exists);

            NSError* err = nil;
            BOOL isDirectory = NO;
            if ([fm fileExistsAtPath:tempFolder isDirectory:&isDirectory]) {
                NSDirectoryEnumerator* en = [fm enumeratorAtPath:tempFolder];
                NSString* file;
                while (file = [en nextObject]) {
                    BOOL res = [fm removeItemAtPath:[tempFolder stringByAppendingPathComponent:file] error:&err];
                    if (!res && err)
                        DDLogError(@"TRRecipeRunner failed to remove %@: %@", file, err);
                }
            } else {
                BOOL res = [fm createDirectoryAtPath:tempFolder withIntermediateDirectories:NO attributes:nil error:&err];
                if (!res && err)
                    DDLogError(@"TRRecipeRunner failed to create %@: %@", tempFolder, err);
            }
        }
    }
    return self;
}
+ (CGImageRef) runRecipe:(TRRecipe*)recipe consumingCGInput:(CGImageRef) CF_CONSUMED cgInput
  masterSize:(CGSize)masterSize CF_RETURNS_RETAINED
{
    CGImageRef img = nil;
    BOOL isLarge = CGImageGetWidth(cgInput) > 1024 || CGImageGetHeight(cgInput) > 1024;

    @autoreleasepool {
        TRRecipeRunner* runner = [[TRRecipeRunner alloc] initWithMasterSize:masterSize isLarge:isLarge];

        if (isLarge) {
            DDLogInfo(@"runRecipe %@ (source image retain count %ld)", recipe.code,
              CFGetRetainCount(cgInput));
        } else {
            DDLogVerbose(@"runRecipe %@", recipe.code);
        }

        TRRecipeCodeParser* p = [[TRRecipeCodeParser alloc] initWithCode:recipe.code];
        @try {
            [runner pushImage:cgInput];
            CGImageRelease(cgInput);
            if (isLarge)
                [runner debugDumpStack:@"runRecipe"];
            [[p tree] visitWithVisitor:runner];
            img = [runner popImage];
            NSAssert(img, @"expected runner popImage to return an image");
            NSAssert(runner->stack.count == 0,
              @"expected TRRecipeRunner stack to be empty, but contains %zd items",
              runner->stack.count);
        }
        @catch (NSException* x) {
            DDLogError(@"runRecipe visitWithVisitor failed: %@", x);
            img = nil;
        }
    }

    if (isLarge) {
        DDLogInfo(@"runRecipe %@ done (result image retain count %ld)", recipe.code,
          CFGetRetainCount(img));
    }
    NSAssert(img, @"runRecipe consumingCGInput returning nil");
    return img;
}

+ (CGImageRef) runRecipe:(TRRecipe*)recipe cgInput:(CGImageRef)cgInput
  masterSize:(CGSize)masterSize CF_RETURNS_RETAINED
{
    CGImageRef result = [TRRecipeRunner runRecipe:recipe consumingCGInput:CGImageRetain(cgInput) masterSize:masterSize];
    NSAssert(result, @"runRecipe cgInput returning nil");
    return result;
}

- (ImageHandle*) topOfStack {
    return [stack lastObject];
}
- (void) debugDumpStack:(NSString*)prefix {
    DDLogVerbose(@"%@ stack %@", prefix, stack);
}
- (void) pushImage:(CGImageRef)img {
    [stack addObject:[[ImageHandle alloc] initWithImage:img]];
    if (isLarge) {
        DDLogInfo(@"%@pushImage img %p refcount=%ld", [self depthString], img, CFGetRetainCount(img));
        [self debugDumpStack:@"pushImage"];
    }
}
- (CGImageRef) popImage CF_RETURNS_RETAINED {
    if (isLarge)
        [self debugDumpStack:@"popImage start"];
    CGImageRef img = nil;
    @autoreleasepool {
        ImageHandle* tos = [self topOfStack];
        img = CGImageRetain(tos.image);
        [stack removeLastObject];
    }
    if (isLarge) {
        [self debugDumpStack:@"popImage end"];
        DDLogInfo(@"%@popImage img %p refcount=%ld", [self depthString], img, CFGetRetainCount(img));
    }
    return img;
}
- (NSString*) depthString {
    return [@"" stringByPaddingToLength:stack.count * 2 withString:@" " startingAtIndex:0];
}
- (void) visitAtom:(TRRecipeNode*)node {
    @autoreleasepool {
        TRStylet* s = [TRStylet styletIdentifiedByCode:node.element];
        if (!s) {
            DDLogError(@"no stylet for %@", node.element);
            return;
        }

        s.masterSize = masterSize;
        if (node.strength >= 98.0) {
            CGImageRef img = self.popImage;
            DDLogVerbose(@"%@runStylet %@ %zd", [self depthString], s.ident, node.strength);
            CGImageRef img2 = [s applyStyletToCGImage:img];
            [self pushImage:img2];
            CGImageRelease(img2);
        } else if (node.strength <= 2.0) {
            // do nothing
        } else {
            ImageHandle* tos = [self topOfStack];
            CGImageRef img = CGImageRetain(tos.image);
            DDLogVerbose(@"%@runStylet %@ %zd", [self depthString], s.ident, node.strength);
            CGImageRetain(img);
            CGImageRef img2 = [s applyStyletToCGImage:img];
            CGImageRef img3 = [TRHelper blendFrom:img to:img2 strength:node.strength / 100.0f];
            CGImageRelease(img);
            CGImageRelease(img2);
            tos.image = img3;
            CGImageRelease(img3);
        }
    }
}

- (void) enterRecipe:(TRRecipeNode*)node {
    @autoreleasepool {
        if (isLarge) {
            DDLogInfo(@"%@enterRecipe %zd", [self depthString], node.strength);
            [self debugDumpStack:@"enterRecipe start"];
        }

        ImageHandle* tos = [self topOfStack];
        CGImageRef img = CGImageRetain(tos.image);
        if (node.strength >= 98.0)
            [tos releaseWithoutSavingToTemporaryFile];
        else
            [tos releaseAfterSavingToTemporaryFile:tempFolder isLarge:isLarge];

        if (isLarge) {
            [self debugDumpStack:@"enterRecipe after saving to temp file"];
            DDLogInfo(@"%@enterRecipe img %p refcount=%ld", [self depthString], img, CFGetRetainCount(img));
        }

        [self pushImage:img];
        CGImageRelease(img);

        if (isLarge)
            [self debugDumpStack:@"enterRecipe end"];
    }
}
- (void) leaveRecipe:(TRRecipeNode*)node {
    @autoreleasepool {
        if (isLarge)
            [self debugDumpStack:@"leaveRecipe start"];

        CGImageRef img2 = self.popImage;

        ImageHandle* tos = [self topOfStack];
        if (node.strength >= 98.0) {
            tos.image = img2;
            CGImageRelease(img2);
        } else {
            [tos restoreFromTemporaryFileAndRetain];
            CGImageRef img = CGImageRetain(tos.image);

            CGImageRef img3 = [TRHelper blendFrom:img to:img2 strength:node.strength / 100.0f];
            CGImageRelease(img);
            CGImageRelease(img2);
            tos.image = img3;
            CGImageRelease(img3);
        }
        
        if (isLarge) {
            DDLogInfo(@"%@leaveRecipe %zd", [self depthString], node.strength);
            [self debugDumpStack:@"leaveRecipe end"];
        }
    }
}
- (void) enterBranch:(TRRecipeNode*)node {
    DDLogVerbose(@"enterBranch");
}
- (void) leaveBranch:(TRRecipeNode*)node {
    DDLogVerbose(@"leaveBranch");
}
@end

@interface TRRecipe ()
@property NSString* normalizedCode;
@end

@implementation TRRecipe

@synthesize code = _code;
@synthesize normalizedCode = _normalizedCode;

- (id)init {
    self = [super init];
    if (self) {
        _code = [[NSMutableString alloc] init];
    }
    return self;
}

- (TRRecipe*) initWithCode:(NSString*)recipeCode {
    self = [super init];
    if (self) {
        _code = recipeCode;
    }
    return self;
}
- (NSString*) description {
    return self.code;
}

- (void) append:(NSString*)recipeCode {
    @synchronized (self) {
        _code = [_code stringByAppendingString:recipeCode];
    }
}

- (NSString*) code {
    @synchronized (self) {
        if (!_normalizedCode)
            _normalizedCode = [TRRecipe normalizedRecipeCode:_code];
        return _normalizedCode;
    }
}

- (void) setCode:(NSString*)code {
    @synchronized (self) {
        _code = code;
        _normalizedCode = nil;
    }
}

- (void) parseNestedRecipe:(TRRecipeCodeTokenizer*)tok array:(NSMutableArray*)array {
    id t = nil;
    while ((t = tok.next)) {
        if ([t isKindOfClass:NSNumber.class]) {
            TRRecipeInstruction* ins = [array lastObject];
            ins.strength = ((NSNumber*)t).integerValue;
        } else {
            NSString* s = (NSString*)t;
            if ([s isEqual:@"("]) {
                NSMutableArray* a = [[NSMutableArray alloc] init];
                [array addObject:a];
                [self parseNestedRecipe:tok array:a];
            } else if ([s isEqual:@")"]) {
                return;
            } else {
                TRRecipeInstruction* ins = [[TRRecipeInstruction alloc] init];
                ins.element = s;
                ins.strength = 100;
            }
        }
    }
}

+ (NSArray*)styletsInRecipeCode:(NSString*)code {
    NSMutableArray* result = [[NSMutableArray alloc] init];
    TRRecipeCodeTokenizer* tok = [[TRRecipeCodeTokenizer alloc] initWithCode:code];
    id t = nil;
    while ((t = tok.next)) {
        if ([t isKindOfClass:NSString.class]) {
            NSString* s = (NSString*)t;
            if (![s isEqual:@"("] && ![s isEqual:@")"])
                [result addObject:s];
        }
    }
    return result;
}

- (CGImageRef) applyToCGImage:(CGImageRef)cgInput masterSize:(CGSize)masterSize
  CF_RETURNS_RETAINED
{
    @autoreleasepool {
        CGImageRef img = [TRRecipeRunner runRecipe:self cgInput:cgInput masterSize:masterSize];
        NSAssert(img, @"applyToCGImage returning nil");
        return img;
    }
}

- (CGImageRef) consumeCGImage:(CGImageRef) CF_CONSUMED cgInput masterSize:(CGSize)masterSize
  CF_RETURNS_RETAINED
{
    DDLogInfo(@"consumeCGImage %p, retain count %ld", cgInput, CFGetRetainCount(cgInput));
    @autoreleasepool {
        CGImageRef img = [TRRecipeRunner runRecipe:self consumingCGInput:cgInput masterSize:masterSize];
        NSAssert(img, @"consumeCGImage returning nil");
        DDLogInfo(@"consumeCGImage %p done, retain count %ld", img, CFGetRetainCount(img));
        return img;
    }
}

+ (NSString*) nameForRecipeCode:(NSString*)code {
    return [TRStatistics nameForCode:code];
}

+ (BOOL) isBuiltin:(NSString*)code {
    return !code || [code isEqual:@""] || [[TRRecipe styletLibrary] containsObject:code];
}

+ (BOOL) isAtomic:(NSString*)code {
    // XXX: In future, builtin might not ALWAYS mean atomic.
    return [TRRecipe isBuiltin:code];
}

+ (NSDictionary *)historicalStyletLibraries {
    static dispatch_once_t once;
    static NSDictionary* lists;
    dispatch_once(&once, ^{
        // Dictionary keys are the maximum build number at which that canonical
        // list of stylet codes is valid
        lists = [NSDictionary dictionaryWithObjectsAndKeys:
            [NSArray arrayWithObjects:
                @"L",  @"D",  @"N",
                @"W",  @"C",  @"M",
                @"Sh", @"Hl", @"Q",
                @"Cr", @"S",  @"V",
                @"Vb", @"G",  @"Hf",
                @"Mc", @"Lf", @"Bt",
                @"Fc", @"Fw", @"Fn",
                @"Lx", @"Br", @"Vk",
                @"Mm", @"Ps", @"Dw",
                @"Sf", @"Fg", @"Rg",
                @"Sj", @"Pt", @"Fl",
                @"Tr", @"Sr", @"Gl",
                @"Pc", @"Sx", @"Pk",
                @"Sb", @"Bk", @"Dt",
                @"Sp", @"Mg", @"Sk",
                @"Mt", @"Dh",
                nil], @53,
            nil];
    });
    return lists;
}

+ (NSArray*) styletLibrary {
    static dispatch_once_t once;
    static NSArray* list;
    dispatch_once(&once, ^{
        if (wantDebugStyletList)
            list = [NSArray arrayWithObjects:
              //@"Zz",
              //@"Sb",
              //@"Lb",
              //@"L",
              //@"D",
              //@"W",
              //@"Lt",
              //@"Dk",
              //@"C",
              //@"Cr",
              //@"Br",
              //@"V",
              @"M",
              @"N",
              @"Q",
              @"Bk",
              //@"Sh",
              //@"Hl",
              nil];
        else
            list = [NSArray arrayWithObjects:
              @"L",  @"D",  @"N",
              @"W",  @"C",  @"M",
              @"Sh", @"Hl", @"Q",
              @"Cr", @"S",  @"V",
              @"Vb", @"G",  @"Hf",
              @"Ft", @"Ms", @"Wk",
              @"Tn", @"Rb", @"Yr",
              @"Mc", @"Lf", @"Bt",
              @"Fc", @"Fw", @"Fn",
              @"Lx", @"Br", @"Vk",
              @"Mm", @"Ps", @"Dw",
              @"Sf", @"Fg", @"Rg",
              @"Sj", @"Pt", @"Fl",
              @"Tr", @"Sr", @"Gl",
              @"Pc", @"Sx", @"Pk",
              @"Sb", @"Bk", @"Dt",
              @"Sp", @"Mg", @"Sk",
              @"Mt", @"Dh", @"Pw",
              @"Rr",
              @"Fb", @"Ig", @"Fr",
              @"Vg",
              @"Xra", @"Xrb", @"Xrc",
              @"Xrd", @"Xre", @"Xrf",
              @"Xrg", @"Xrh", @"Xri",
              @"Xrj",
              nil];
    });
    return list;
}

+ (NSArray*) namedRecipes {
    NSMutableArray* result = [[NSMutableArray alloc] init];
    [[TRStatistics namedRecipeList] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop){
        [result addObject:[(TRNamedRecipe*)obj recipe_code]];
    }];
    return result;
}

+ (NSArray*) historyListOfSize:(NSUInteger)size {
    return nil;
}

+ (NSArray*) magicList {
    return nil;
}

+ (NSString*) normalizedRecipeCode:(NSString*)code {
    TRRecipeCodeParser* par = [[TRRecipeCodeParser alloc] initWithCode:code];
    TRRecipeNode* t = [par tree];
    [t normalize];
    return t.description;
}

+ (void)purgeCaches {
    [TRStylet purgeStyletPreflightCache];
}

@end

@interface TRRecipeTester : NSObject <TRRecipeNodeVisitor>
@end

@implementation TRRecipeTester {
    NSUInteger depth;
}
+ (void) testRecipe:(TRRecipe*)recipe {
    TRRecipeCodeParser* p = [[TRRecipeCodeParser alloc] initWithCode:recipe.code];
    TRRecipeNode* tree = [p tree];
    TRRecipeTester* tester = [[TRRecipeTester alloc] init];
    [tree visitWithVisitor:tester];
}
- (NSString*) depthString {
    return [@"" stringByPaddingToLength:depth * 2 withString:@" " startingAtIndex:0];
}
- (void) visitAtom:(TRRecipeNode*)node {
    DDLogVerbose(@"%@visitAtom %@", [self depthString], node);
}
- (void) enterRecipe:(TRRecipeNode*)node {
    DDLogVerbose(@"%@enterRecipe", [self depthString]);
    ++depth;
}
- (void) leaveRecipe:(TRRecipeNode*)node {
    --depth;
    DDLogVerbose(@"%@leaveRecipe %zd", [self depthString], node.strength);
}
- (void) enterBranch:(TRRecipeNode*)node {
    DDLogVerbose(@"enterBranch");
}
- (void) leaveBranch:(TRRecipeNode*)node {
    DDLogVerbose(@"leaveBranch");
}
@end

@interface TRRecipeDumper() <TRRecipeNodeVisitor>
@property TRRecipeNode* root;
@property NSMutableString* desc;
@end

@implementation TRRecipeDumper
- (TRRecipeDumper*) initWithCode:(NSString*)code {
    TRRecipeCodeParser* par = [[TRRecipeCodeParser alloc] initWithCode:code];
    return [[TRRecipeDumper alloc] initWithTree:[par tree]];
}
- (TRRecipeDumper*) initWithTree:(TRRecipeNode*)tree {
    self = [super init];
    if (self) {
        self.root = tree;
    }
    return self;
}

- (NSString*) description {
    if (!self.desc) {
        self.desc = [[NSMutableString alloc] init];
        [self.root visitWithVisitor:self];
    }
    return self.desc;
}
- (void) appendStrengthForNode:(TRRecipeNode*)node {
    if (node.strength < 100) {
        if (node.strength % 10 == 0)
            [self.desc appendFormat:@"%zd", node.strength / 10];
        else
            [self.desc appendFormat:@"%02zd", node.strength];
    }
}
- (void) visitAtom:(TRRecipeNode*)node {
    [self.desc appendString:node.element];
    [self appendStrengthForNode:node];
}
- (void) enterRecipe:(TRRecipeNode*)node {
    [self.desc appendString:@"("];
}
- (void) leaveRecipe:(TRRecipeNode*)node {
    [self.desc appendString:@")"];
    [self appendStrengthForNode:node];
}
- (void) enterBranch:(TRRecipeNode*)node {}
- (void) leaveBranch:(TRRecipeNode*)node {}
@end
