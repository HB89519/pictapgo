//
//  TRRecipeParseTest.m
//  RadLab
//
//  Created by Tim Ruddick on 1/23/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import "TRRecipeParseTest.h"
#import "TRRecipe.h"

@implementation TRRecipeParseTest

- (void)setUp
{
    [super setUp];

    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.

    [super tearDown];
}

- (CGImageRef) testImage CF_RETURNS_RETAINED {
    NSBundle* myBundle = [NSBundle bundleForClass:[TRRecipeParseTest class]];
    NSString* pngPath = [myBundle pathForResource:@"cube-lofi" ofType:@"png"];
    NSAssert(pngPath, @"testImage pngPath is nil");
    CGDataProviderRef provider =
      CGDataProviderCreateWithFilename([pngPath fileSystemRepresentation]);
    NSAssert(provider, @"testImage provider is nil");

    CGImageRef img = CGImageCreateWithPNGDataProvider(provider, NULL, false,
      kCGRenderingIntentDefault);
    CGDataProviderRelease(provider);

    return img;
}

NSArray* A(NSString* s1, NSString* s2) {
    return [NSArray arrayWithObjects:s1, s2, nil];
}

- (void)testRecipeTrees
{
    //@"A[LM:CDE]7",
    NSDictionary* codes = [NSDictionary dictionaryWithObjectsAndKeys:
      A(@"(L)",               @"L"),              @"L",
      A(@"(LD)",              @"LD"),             @"LD",
      A(@"((LD)2)",           @"(LD)2"),          @"(LD)2",
      A(@"(L(DCr)Br)",        @"LDCrBr"),         @"L(DCr)Br",
      A(@"(L6(DCr)Br)",       @"L6DCrBr"),        @"L6(DCr)Br",
      A(@"(L(D3Cr)Br)",       @"LD3CrBr"),        @"L(D3Cr)Br",
      A(@"(L(DCr)7Br)",       @"L(DCr)7Br"),      @"L(DCr)70Br",
      A(@"(L(DCr)Br1)",       @"LDCrBr1"),        @"L(DCr)Br1",
      A(@"(Q(LCr)D)",         @"QLCrD"),          @"Q(LCr)D",
      A(@"(Q6(L3Cr4)D)",      @"Q6L3Cr4D"),       @"Q6(L3Cr4)D",
      A(@"(Q6(L3Cr4)D7)",     @"Q6L3Cr4D7"),      @"Q6(L3Cr40)D7",
      A(@"(Q6(L3Cr4)2D7)",    @"Q6(L3Cr4)2D7"),   @"Q6(L3Cr4)2D7",
      A(@"(Q(L(CrD)W)V)",     @"QLCrDWV"),        @"Q(L(CrD)W)V",
      A(@"(Q(L(CrD)2W)V)",    @"QL(CrD)2WV"),     @"Q(L(CrD)2W)V",
      A(@"((LBC)(LBC)LBC)",   @"LBCLBCLBC"),      @"(LBC)(LBC)LBC",
      A(@"((LBC)LBC(LBC))",   @"LBCLBCLBC"),      @"(LBC)LBC(LBC)",
      nil];

    CGImageRef testimage = [self testImage];
    STAssertTrue(testimage, @"null testimage");
    for (NSString* code in codes) {
        NSLog(@"### %@ ###", code);
        NSString* dumped = [[codes objectForKey:code] objectAtIndex:0];
        NSString* expected = [[codes objectForKey:code] objectAtIndex:1];

        if (NO) {
            TRRecipeCodeTokenizer* tok = [[TRRecipeCodeTokenizer alloc] initWithCode:code];
            id i;
            while ((i = tok.next))
                NSLog(@"token: %@", i);
        }

        {
            TRRecipeCodeParser* par = [[TRRecipeCodeParser alloc] initWithCode:code];
            TRRecipeNode* tree = [par tree];
            NSString* d = [tree description];
            STAssertEqualObjects(d, expected, @"for normalized \"%@\"", code);
            TRRecipeDumper* dumper = [[TRRecipeDumper alloc] initWithCode:code];
            NSString* dstr = dumper.description;
            STAssertEqualObjects(dstr, dumped, @"for dumped \"%@\"", code);
        }

        TRRecipe* r = [[TRRecipe alloc] initWithCode:[TRRecipe normalizedRecipeCode:code]];

        CGImageRef result = [r applyToCGImage:testimage masterSize:CGSizeMake(3000, 2000)];
        CGImageRelease(result);
    }
    CGImageRelease(testimage);
}

- (void)testTrivial {
    STAssertEquals(1, 1, @"trivial test failed");
}

@end
