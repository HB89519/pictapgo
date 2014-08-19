//
//  TRStatistics.m
//  Stylet
//
//  Created by Tim Ruddick on 1/21/13.
//  Copyright (c) 2013 Totally Rad!. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "TRRecipe.h"
#import "TRStatistics.h"
#import "TRMagicWeight.h"
#import "TRUploadState.h"
#import "TRCrashInfo.h"
#import "TRJSONSerialization.h"
#import <AdSupport/AdSupport.h>
#import "UIDevice-Hardware.h"
#import "Appirater.h"
#import "DDLog.h"
#import "TRFacebookIntegration.h"

#define WHERE_STRX(x) #x
#define WHERE_STR(x) WHERE_STRX(x)
#define WHERE @__FILE__ ":" WHERE_STR(__LINE__)

static int ddLogLevel = LOG_LEVEL_INFO;

@interface TRStatistics () <NSURLConnectionDelegate>
+ (TRStatistics*) manager;
@property (strong, atomic) NSManagedObjectModel* managedObjectModel;
@property (strong, atomic) NSPersistentStoreCoordinator* persistentStoreCoordinator;
@property (strong, atomic) NSManagedObjectContext* managedObjectContext;
@property (strong, nonatomic) NSArray* trustedHosts;
@property (strong, atomic) NSNumber* uploadFrontier;
@property (strong, atomic) NSUUID* deviceId;
@property (strong, atomic) NSMutableDictionary* lockedCodes;
@property (strong, atomic) NSMutableDictionary* lockedTypes;
@property (strong, atomic) NSMutableSet* lockableCodes;
@end

@implementation TRStatistics

static NSString* unlockCodePrefix = @"Unl";

static TRStatistics* _manager;

- (id)init {
    self = [super init];
    if (!self)
        return self;

    self.trustedHosts = [NSArray arrayWithObject:@"stats.pictapgo.com"];
    self.lockedCodes = [[NSMutableDictionary alloc] init];
    self.lockedTypes = [[NSMutableDictionary alloc] init];
    self.lockableCodes = [[NSMutableSet alloc] init];

    NSBundle* myBundle = [NSBundle bundleForClass:[TRStatistics class]];
    NSString* modelPath = [myBundle pathForResource:@"Statistics" ofType:@"momd"];
    NSURL* modelURL = [NSURL fileURLWithPath:modelPath];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    NSAssert(_managedObjectModel, @"failed to create managedObjectModel");

    NSString* applicationDocumentsDirectory = nil;
    if (NSClassFromString(@"SenTest")) {
        applicationDocumentsDirectory = NSTemporaryDirectory();
        NSLog(@"Unit Test TR.sqlite store in %@", applicationDocumentsDirectory);
    } else {
        NSArray* docDirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        applicationDocumentsDirectory = [docDirs lastObject];
    }
    
    NSURL* storeURL = [NSURL fileURLWithPath:[applicationDocumentsDirectory
      stringByAppendingPathComponent:@"TR.sqlite"]];
    _persistentStoreCoordinator =
      [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:_managedObjectModel];
    NSAssert(_persistentStoreCoordinator, @"failed to create persistentStoreCoordinator");

    NSError* error = nil;
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
      [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
      [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption,
      nil];
    for (int i = 0; i < 2; ++i) {
        if ([_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
          configuration:nil URL:storeURL options:options error:&error])
            break;
        else {
            // Delete file and retry.
            // TODO: Need to try harder to recover user's recipes and history.
            DDLogError(@"failed to setup persistent store: \"%@\"; deleting and retrying", [error localizedDescription]);
            DDLogError(@"***** ***** ***** NEED TO FIX THIS!!! ***** ***** *****");
            if ([[NSFileManager defaultManager] fileExistsAtPath:storeURL.path]) {
                if (![[NSFileManager defaultManager] removeItemAtPath:storeURL.path error:&error]) {
                    [NSException raise:@"StatisticsError" format:@"failed to delete %@: %@", storeURL, error];
                }
            }

        }
    }

    _managedObjectContext = [[NSManagedObjectContext alloc] init];
    _managedObjectContext.persistentStoreCoordinator = _persistentStoreCoordinator;

    return self;
}

+ (TRStatistics*) manager {
    static dispatch_once_t once;
    dispatch_once(&once, ^(void){
        _manager = [[TRStatistics alloc] init];
    });
    return _manager;
}

NSDictionary* VAL(NSString* name) {
    return [NSMutableDictionary dictionaryWithObjectsAndKeys:
      name, @"name",
      @0, @"weight",
      nil];
}

NSDictionary* LOCKEDVAL(NSString* name, LockedRecipeCodeType type, NSArray* urlsForUnlock) {
    return [NSMutableDictionary dictionaryWithObjectsAndKeys:
      name, @"name",
      @0, @"weight",
      [NSNumber numberWithInt:type], @"lockedType",
      urlsForUnlock, @"urlsForUnlock",
      nil];
}

+ (void) prepopulate {
    TRStatistics* mgr = [TRStatistics manager];
    NSDictionary* names = [NSDictionary dictionaryWithObjectsAndKeys:
      VAL(@"Empty"),             @"Zz",
      VAL(@"Simple BW"),         @"Sb",
      //VAL(@"L*ab BW"),           @"Lb",
      VAL(@"Lights On"),         @"L",
      VAL(@"Lights Out"),        @"D",
      VAL(@"Warm It Up"),        @"W",
      VAL(@"Cool It Down"),      @"C",
      VAL(@"Crispity"),          @"Cr",
      VAL(@"Brightside"),        @"Br",
      VAL(@"EZ-Burn"),           @"V",
      VAL(@"Equalize"),          @"Q",

      VAL(@"Highlights"),        @"Hl",
      VAL(@"Shadows"),           @"Sh",
      VAL(@"Sweet Tooth"),       @"Vb",
      VAL(@"Paperboy"),          @"Dh",
      VAL(@"Crossed-Up"),        @"Pc",
      VAL(@"Crossroads"),        @"Pk",

      VAL(@"Auto Contrast"),     @"N",
      VAL(@"Auto Color"),        @"M",
      VAL(@"Grainstorm"),        @"G",
      VAL(@"+ Contrast"),        @"S",
      VAL(@"Faux-Fi"),           @"Lf",
      VAL(@"High Fives"),        @"Hf",
      VAL(@"Fade to Gray"),      @"Fn",
      VAL(@"Fade to Autumn"),    @"Fc",
      VAL(@"Fade to Summer"),    @"Fw",
      VAL(@"Vanilla Kiss"),      @"Vk",
      VAL(@"Pistachio"),         @"Ps",
      VAL(@"Dream World"),       @"Dw",
      VAL(@"Super Fun Happy"),   @"Sf",
      VAL(@"Pool Party"),        @"Pt",
      VAL(@"Orange You Glad"),   @"Rg",
      VAL(@"Skinny Jeans"),      @"Sj",
      VAL(@"Old Glory"),         @"Gl",
      VAL(@"SX-70"),             @"Sx",
      VAL(@"Flirt"),             @"Fl",
      VAL(@"Troy"),              @"Tr",
      VAL(@"Bleached"),          @"Bt",
      VAL(@"Flare Up"),          @"Fg",
      VAL(@"Montecito"),         @"Mc",
      VAL(@"Sugar Rush"),        @"Sr",
      VAL(@"Lux"),               @"Lx",
      VAL(@"Mama’s Tap Shoes"),  @"Mm",
      VAL(@"Old Skool"),         @"Sk",
      VAL(@"Detroit"),           @"Dt",
      VAL(@"Salt + Pepper"),     @"Sp",
      VAL(@"Alabaster"),         @"Mg",
      VAL(@"Metropolis"),        @"Mt",
      VAL(@"Brooklyn"),          @"Bk",
      VAL(@"Terra"),             @"Rr",

      VAL(@"Awake"),             @"Wk",
      VAL(@"Randsburg"),         @"Rb",
      VAL(@"Loft"),              @"Ft",
      VAL(@"Eternal"),           @"Tn",
      VAL(@"Air"),               @"Yr",
      VAL(@"Mason"),             @"Ms",
      VAL(@"Powder"),            @"Pw",
                           
      VAL(@"400H"),              @"Xra",
      VAL(@"800Z"),              @"Xrb",
      VAL(@"RAP 100F"),          @"Xrc",
      VAL(@"Ekt 25"),            @"Xrd",
      VAL(@"RVP 50"),            @"Xre",
      VAL(@"P 160NC"),           @"Xrf",
      VAL(@"3200 TMZ"),          @"Xrg",
      VAL(@"Scl 200X"),          @"Xrh",
      VAL(@"400TX"),             @"Xri",
      VAL(@"AgPro 200"),         @"Xrj",
                           
                           
                           
      LOCKEDVAL(@"Milk & Cookies", LockedRecipeCodeFacebook,
        @[
          [@"fb://profile/" stringByAppendingString:FacebookPageIdPicTapGo],
          @"http://facebook.com/pictapgo"
        ]), @"Fb",

      LOCKEDVAL(@"Pier Pressure", LockedRecipeCodeInstagram,
        @[
          @"instagram://user?username=pictapgo",
          @"http://instagram.com/pictapgo"
        ]), @"Ig",

      LOCKEDVAL(@"SloBurn", LockedRecipeCodeTwitter,
        @[
          @"twitter://user?screen_name=pictapgo",
          @"http://twitter.com/pictapgo"
        ]), @"Vg",

      LOCKEDVAL(@"Fade to Winter", LockedRecipeCodeMailingList,
        @[
          @"http://www.pictapgo.com/mailing-list/?ref=ptg_app"
        ]), @"Fr",

      //VAL(@"Exposure +½"),       @"Lt",
      //VAL(@"Exposure -½"),       @"Dk",
      //VAL(@"Oh, Snap!"),         @"Sn",
      //VAL(@"Portland"),          @"Pr",

      nil];

    if (YES) {
        NSArray* styletLibrary = [TRRecipe styletLibrary];
        NSMutableSet* namedList = [[NSMutableSet alloc] init];
        for (NSString* k in names)
            if (![k isEqual:@"Zz"])
                [namedList addObject:k];
        NSMutableSet* inLibraryButNotNamed = [NSMutableSet setWithArray:styletLibrary];
        [inLibraryButNotNamed minusSet:namedList];
        NSMutableSet* inNamedButNotLibrary = [namedList mutableCopy];
        [inNamedButNotLibrary minusSet:[NSSet setWithArray:styletLibrary]];
        if ([inNamedButNotLibrary count] > 0) {
            DDLogWarn(@"!!!! in stats list but not library: %@",
              [[inNamedButNotLibrary allObjects] componentsJoinedByString:@" "]);
        }
        if ([inLibraryButNotNamed count] > 0) {
            DDLogWarn(@"!!!! in library but not stats list: %@",
              [[inLibraryButNotNamed allObjects] componentsJoinedByString:@" "]);
        }
    }

    [names enumerateKeysAndObjectsUsingBlock:^(NSString* code, NSDictionary* obj, BOOL *stop){
        [mgr initializeBuiltinCode:code values:obj];
    }];

    DDLogVerbose(@"locked recipe codes: %@", mgr.lockedCodes);
    
  #ifndef CONFIGURATION_AppStore
    [mgr sanityCheckRecipeCodes];
  #endif
}

- (void)sanityCheckRecipeCodes {
    NSFetchRequest* fetchRequest = [self.managedObjectModel
      fetchRequestTemplateForName:@"fetchAllUserRecipes"];
    NSAssert(fetchRequest, WHERE);

    NSError* error = nil;
    NSArray* fetchedObjects = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (error)
        [NSException raise:@"StatisticsError" format:@"%@", error];
    for (TRNamedRecipe* r in fetchedObjects) {
        DDLogVerbose(@"recipe %@: \"%@\"", r.recipe_code, r.recipe_name);
        @try {
            DDLogVerbose(@"sanity checking recipe \"%@\"", r.recipe_code);
            TRRecipeCodeParser* par = [[TRRecipeCodeParser alloc] initWithCode:r.recipe_code];
            TRRecipeNode* t = [par tree];   // attempt to parse recipe code
            [t normalize];
            NSString* normstr = t.description;
            if (![r.recipe_code isEqual:normstr]) {
                DDLogWarn(@"recipe code \"%@\" should be \"%@\"; changing", r.recipe_code, normstr);
                r.recipe_code = normstr;
            }
        }
        @catch (NSException* x) {
            DDLogError(@"insane code \"%@\" in recipes; will attempt to delete it", r.recipe_code);
            [self.managedObjectContext deleteObject:r];
        }
    }

    fetchRequest =
      [NSFetchRequest fetchRequestWithEntityName:@"TRUsageHistory"];
    NSAssert(fetchRequest, WHERE);
    fetchedObjects = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (error)
        [NSException raise:@"StatisticsError" format:@"%@", error];
    for (TRUsageHistory* h in fetchedObjects) {
        DDLogVerbose(@"history %@: %@", h.recipe_code, h.timestamp);
        @try {
            DDLogVerbose(@"sanity checking history \"%@\"", h.recipe_code);
            TRRecipeCodeParser* par = [[TRRecipeCodeParser alloc] initWithCode:h.recipe_code];
            TRRecipeNode* t = [par tree];   // attempt to parse recipe code
            [t normalize];
            NSString* normstr = t.description;
            if (![h.recipe_code isEqual:normstr]) {
                DDLogWarn(@"history recipe code \"%@\" should be \"%@\"; changing", h.recipe_code, normstr);
                h.recipe_code = normstr;
            }
        }
        @catch (NSException* x) {
            DDLogError(@"insane code \"%@\" in history; will attempt to delete it", h.recipe_code);
            [self.managedObjectContext deleteObject:h];
        }
    }
    [self.managedObjectContext save:&error];
    if (error)
        DDLogError(@"sanityCheckRecipeCodes save failed: %@", error);
}

- (TRUploadState*)mostRecentUploadState {
    NSFetchRequest* fetchRequest =
      [NSFetchRequest fetchRequestWithEntityName:@"TRUploadState"];
    NSAssert(fetchRequest, WHERE);
    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:
      [[NSSortDescriptor alloc] initWithKey:@"timestamp" ascending:NO]]];
    NSError* error = nil;
    NSArray* fetchedObjects = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];

    if (error) {
        DDLogError(@"error fetching stats state: %@", error);
        return nil;
    } else if (fetchedObjects.count > 0) {
        TRUploadState* s = [fetchedObjects objectAtIndex:0];
        return s;
    } else {
        DDLogError(@"fetching stats state return empty set");
        return nil;
    }
}

+ (NSUUID*)deviceIdentifier {
    TRStatistics* mgr = [TRStatistics manager];
    NSUUID* devId = mgr.deviceId;
    if (devId)
        return devId;

    TRUploadState* s = [mgr mostRecentUploadState];
    if (s) {
        if (s.user_uuid_old.length == 0) {
            s.user_uuid_old = s.user_uuid;
            s.user_uuid = [[[NSUUID alloc] init] UUIDString];
            NSError* error = nil;
            [mgr.managedObjectContext save:&error];
            if (error)
                DDLogError(@"failed to create new-style user-id");
        }
        devId = [[NSUUID alloc] initWithUUIDString:s.user_uuid];
    } else {
        // no id assigned yet, so make a new one
        devId = [[NSUUID alloc] init];
    }
    mgr.deviceId = devId;

    return devId;
}

#ifdef USE_APPIRATER
- (void)addAppiraterStatsToDictionary:(NSMutableDictionary*)dict {
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    NSInteger i = [userDefaults integerForKey:kAppiraterUseCount];
    if (i > 0)
        [dict setValue:[NSNumber numberWithInteger:i] forKey:@"rateUses"];

    i = [userDefaults integerForKey:kAppiraterSignificantEventCount];
    if (i > 0)
        [dict setValue:[NSNumber numberWithInteger:i] forKey:@"rateSigEvents"];

    BOOL b = [userDefaults boolForKey:kAppiraterDeclinedToRate];
    if (b)
        [dict setValue:[NSNumber numberWithBool:YES] forKey:@"rateDeclined"];

    b = [userDefaults boolForKey:kAppiraterRatedCurrentVersion];
    if (b)
        [dict setValue:[NSNumber numberWithBool:YES] forKey:@"rateRated"];

    NSTimeInterval t = [userDefaults doubleForKey:kAppiraterReminderRequestDate];
    if (t > 86400 * 2) // allow a couple of days defensive slop for timezone around 1/1/1970
        [dict setValue:[NSNumber numberWithLongLong:t] forKey:@"rateRemind"];
}
#else
- (void)addAppiraterStatsToDictionary:(NSMutableDictionary*)dict {}
#endif

- (NSDictionary*)historyItems {
    NSDictionary* infoDictionary = [[NSBundle mainBundle] infoDictionary];
    NSString* majorVersion = [infoDictionary objectForKey:@"CFBundleShortVersionString"];
    NSString* minorVersion = [infoDictionary objectForKey:@"CFBundleVersion"];
    NSString* specificModel = [[UIDevice currentDevice] platform];
    NSString* osVersion = [[UIDevice currentDevice] systemVersion];

    NSString* modelVersion = [self.managedObjectModel.versionIdentifiers anyObject];

    // Figure out when we last successfully uploaded history
    NSDate* frontier = [NSDate dateWithTimeIntervalSince1970:0];
    NSDate* newFrontier = [NSDate date];
    NSString* userId = [TRStatistics deviceIdentifier].UUIDString;
    NSString* savedUserId = nil;
    NSString* userEmail = nil;

    NSFetchRequest* fetchRequest =
      [NSFetchRequest fetchRequestWithEntityName:@"TRUploadState"];
    NSAssert(fetchRequest, WHERE);
    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:
      [[NSSortDescriptor alloc] initWithKey:@"timestamp" ascending:NO]]];
    NSError* error = nil;
    NSArray* fetchedObjects = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (error)
        DDLogError(@"error fetching stats state: %@", error);

    if (fetchedObjects.count > 0) {
        TRUploadState* s = [fetchedObjects objectAtIndex:0];
        frontier = s.timestamp;
        savedUserId = s.user_uuid_old;
        userEmail = s.user_email_address;
    }

    // gather history since the frontier date
    fetchRequest =
      [NSFetchRequest fetchRequestWithEntityName:@"TRUsageHistory"];
    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:
      [[NSSortDescriptor alloc] initWithKey:@"timestamp" ascending:YES]]];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"timestamp >= %@", frontier]];
    NSAssert(fetchRequest, WHERE);
    NSArray* usageHistory = representationForJSON(
      [self.managedObjectContext executeFetchRequest:fetchRequest error:&error]);

    // gather share destinations since the frontier date
    fetchRequest =
      [NSFetchRequest fetchRequestWithEntityName:@"TRShareHistory"];
    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:
      [[NSSortDescriptor alloc] initWithKey:@"timestamp" ascending:YES]]];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"timestamp >= %@", frontier]];
    NSAssert(fetchRequest, WHERE);
    NSArray* shareHistory = representationForJSON(
      [self.managedObjectContext executeFetchRequest:fetchRequest error:&error]);

    // gather all named recipes
    fetchRequest = [self.managedObjectModel
      fetchRequestTemplateForName:@"fetchAllUserRecipes"];
    NSAssert(fetchRequest, WHERE);
    NSArray* namedRecipe = representationForJSON(
      [self.managedObjectContext executeFetchRequest:fetchRequest error:&error]);

    // gather all magic weights of any significance
    fetchRequest =
      [NSFetchRequest fetchRequestWithEntityName:@"TRMagicWeight"];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"weight > 0.05"]];
    NSAssert(fetchRequest, WHERE);
    NSArray* sortedWeights =
      [[self.managedObjectContext executeFetchRequest:fetchRequest error:&error]
        sortedArrayUsingComparator:^(TRMagicWeight* w1, TRMagicWeight* w2){
          return [w2.weight compare:w1.weight];
        }];
    NSArray* magicWeight = representationForJSON(sortedWeights);

    // gather list of checkpoint codes
    fetchRequest =
      [NSFetchRequest fetchRequestWithEntityName:@"TRCheckpointEvent"];
    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:
      [[NSSortDescriptor alloc] initWithKey:@"timestamp" ascending:YES]]];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"timestamp >= %@", frontier]];
    NSAssert(fetchRequest, WHERE);
    NSArray* checkpointEvents = representationForJSON(
      [self.managedObjectContext executeFetchRequest:fetchRequest error:&error]);

    // crash info
    int crashCount = [TRStatistics crashCount];

    // assemble the results into a dictionary for the caller
    NSMutableDictionary* result = [NSMutableDictionary dictionaryWithObjectsAndKeys:
      modelVersion, @"version",
      userId, @"userId",
      majorVersion, @"appVersion",
      minorVersion, @"appMinorVersion",
      specificModel, @"device",
      osVersion, @"osVersion",
      [NSNumber numberWithLongLong:frontier.timeIntervalSince1970], @"frontier",
      [NSNumber numberWithLongLong:newFrontier.timeIntervalSince1970], @"newFrontier",
      nil];
    if (savedUserId && ![savedUserId isEqual:userId])
        [result setValue:savedUserId forKey:@"savedUserId"];
    if (userEmail && userEmail.length > 0)
        [result setValue:userEmail forKey:@"userEmail"];
    [self addAppiraterStatsToDictionary:result];
    if (usageHistory.count > 0 || shareHistory.count > 0) {
        [result addEntriesFromDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
          usageHistory, @"TRUsageHistory",
          shareHistory, @"TRShareHistory",
          namedRecipe, @"TRNamedRecipe",
          magicWeight, @"TRMagicWeight",
          nil]];
    }
    if (checkpointEvents.count > 0)
        [result setValue:checkpointEvents forKey:@"checkpoints"];
    if (crashCount > 0)
        [result setValue:[NSNumber numberWithInt:crashCount] forKey:@"crashCount"];

  #ifdef USE_UDID_FOR_BUG_TRACKER
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [result addEntriesFromDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
      [[UIDevice currentDevice] uniqueIdentifier], @"udid", nil]];
    #pragma clang diagnostic pop
  #endif

    return result;
}
- (void)uploadFinished:(NSHTTPURLResponse*)rsp {

    NSDate* frontier = [NSDate dateWithTimeIntervalSince1970:self.uploadFrontier.longLongValue];;
    self.uploadFrontier = nil;

    if (rsp.statusCode < 200 || rsp.statusCode > 299) {
        DDLogWarn(@"stats received HTTP response code: %zd", rsp.statusCode);
        return;
    }

    NSFetchRequest* fetchRequest =
      [NSFetchRequest fetchRequestWithEntityName:@"TRUploadState"];
    NSError* error = nil;
    NSArray* fetchedObjects = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];

    TRUploadState* s = nil;
    if (fetchedObjects.count < 1) {
        s = [NSEntityDescription
          insertNewObjectForEntityForName:@"TRUploadState"
          inManagedObjectContext:self.managedObjectContext];
    } else {
        s = [fetchedObjects objectAtIndex:0];
    }

    NSString* userId = [TRStatistics deviceIdentifier].UUIDString;
    if (![s.user_uuid isEqual:userId])
        s.user_uuid = userId;
    if (![s.user_uuid_old isEqual:s.user_uuid])
        s.user_uuid_old = s.user_uuid;
    if (![s.timestamp isEqual:frontier])
        s.timestamp = frontier;

    error = nil;
    [self.managedObjectContext save:&error];
    if (error)
        DDLogError(@"failed to save stats timestamp: %@", error);
    else
        DDLogError(@"updated stats frontier to %@", frontier);
}

+ (void)ping {
    NSUUID* userId = [TRStatistics deviceIdentifier];
    if (!userId)
        return;

    TRStatistics* mgr = [TRStatistics manager];
    NSDictionary* historyItems = [mgr historyItems];
    if (!historyItems)
        return;

    mgr.uploadFrontier = [historyItems objectForKey:@"newFrontier"];
    NSURL* pingURL = [NSURL URLWithString:@"https://stats.pictapgo.com/ptglog.php"];

    NSError* error = nil;
    NSMutableURLRequest* req = [NSMutableURLRequest requestWithURL:pingURL
      cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:60.0];
    req.HTTPMethod = @"POST";
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:historyItems options:0 error:&error];
    //DDLogVerbose(@"http body: %@", [[NSString alloc] initWithData:req.HTTPBody encoding:NSUTF8StringEncoding]);

    [NSURLConnection connectionWithRequest:req delegate:mgr];
}

+ (void)resetMagic {
    TRStatistics* mgr = [TRStatistics manager];
    NSFetchRequest* allWeights =
      [NSFetchRequest fetchRequestWithEntityName:@"TRMagicWeight"];
    NSAssert(allWeights, WHERE);
    allWeights.includesPropertyValues = NO;

    NSError* error = nil;
    NSArray* fetchedObjects = [mgr.managedObjectContext
      executeFetchRequest:allWeights error:&error];
    if (error)
        [NSException raise:@"StatisticsError" format:@"%@", error];
    for (TRMagicWeight* w in fetchedObjects)
        [mgr.managedObjectContext deleteObject:w];
    [mgr.managedObjectContext save:&error];
    if (error)
        DDLogError(@"failed to save changes in resetMagic");

    [TRStatistics prepopulate];
}

+ (void)deleteAllHistory {
    TRStatistics* mgr = [TRStatistics manager];
    NSFetchRequest* allHistory =
      [NSFetchRequest fetchRequestWithEntityName:@"TRUsageHistory"];
    NSAssert(allHistory, WHERE);
    allHistory.includesPropertyValues = NO;

    NSError* error = nil;
    NSArray* fetchedObjects = [mgr.managedObjectContext
      executeFetchRequest:allHistory error:&error];
    if (error)
        [NSException raise:@"StatisticsError" format:@"%@", error];
    for (TRUsageHistory* h in fetchedObjects)
        [mgr.managedObjectContext deleteObject:h];
    [mgr.managedObjectContext save:&error];
    if (error)
        DDLogError(@"failed to save changes in deleteAllHistory");
}

+ (void)deleteAllNames {
    TRStatistics* mgr = [TRStatistics manager];
    NSFetchRequest* allUserRecipes = [mgr.managedObjectModel
      fetchRequestTemplateForName:@"fetchAllUserRecipes"];
    NSAssert(allUserRecipes, WHERE);

    // can't do this for named fetch requests
    //allUserRecipes.includesPropertyValues = NO;

    NSError* error = nil;
    NSArray* fetchedObjects = [mgr.managedObjectContext
      executeFetchRequest:allUserRecipes error:&error];
    if (error)
        [NSException raise:@"StatisticsError" format:@"%@", error];
    for (TRNamedRecipe* r in fetchedObjects)
        [mgr.managedObjectContext deleteObject:r];
    [mgr.managedObjectContext save:&error];
    if (error)
        DDLogError(@"failed to save changes in deleteAllNames");
}

+ (void)resetUnlockedFilters {
    TRStatistics* mgr = [TRStatistics manager];

    int count = 0;
    for (NSString* c in mgr.lockableCodes) {
        NSString* chk = [TRStatistics checkpointNameForUnlockedRecipeCode:c];
        DDLogInfo(@"reset checkpoint %@ for %@", chk, c);
        TRCheckpointEvent* ev = [mgr findCheckpointEvent:chk];
        if (ev) {
            ++count;
            [mgr.managedObjectContext deleteObject:ev];
        }
    }
    if (count) {
        NSError* error = nil;
        [mgr.managedObjectContext save:&error];
        if (error)
            DDLogError(@"failed to save changes in resetUnlockedFilters");
    }
}

+ (void)recipeWasUsed:(NSString*)code {
    DDLogInfo(@"recipeWasUsed %@", code);
    NSDate* now = [NSDate date];

    TRStatistics* mgr = [TRStatistics manager];
    TRUsageHistory* h = [NSEntityDescription
      insertNewObjectForEntityForName:@"TRUsageHistory"
      inManagedObjectContext:mgr.managedObjectContext];

    h.timestamp = now;
    h.recipe_code = code;

    NSError* error = nil;
    if (![mgr.managedObjectContext save:&error]) {
        DDLogError(@"failed to save TRUsageHistory: %@", [error localizedDescription]);
    }
}

+ (void)imageWasShared:(NSString*)destination usingRecipe:(NSString*)recipeCode {
    DDLogInfo(@"imageWasShared %@", destination);
    NSDate* now = [NSDate date];

    TRStatistics* mgr = [TRStatistics manager];
    TRShareHistory* h = [NSEntityDescription
      insertNewObjectForEntityForName:@"TRShareHistory"
      inManagedObjectContext:mgr.managedObjectContext];

    h.timestamp = now;
    h.share_destination = destination;
    h.recipe_code = recipeCode;

    NSError* error = nil;
    if (![mgr.managedObjectContext save:&error]) {
        DDLogError(@"failed to save TRShareHistory: %@", [error localizedDescription]);
    }
}

- (TRCheckpointEvent*)findCheckpointEvent:(NSString*)checkpoint {
    NSFetchRequest* fetchRequest = [self.managedObjectModel
      fetchRequestFromTemplateWithName:@"fetchCheckpointForCode"
      substitutionVariables:[NSDictionary dictionaryWithObjectsAndKeys:
        checkpoint, @"CHECKPOINT_CODE", nil]];
    NSAssert(fetchRequest, WHERE);

    NSError* error = nil;
    NSArray* fetchedObjects = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (error) {
        DDLogError(@"failed to find checkpoint for %@: %@", checkpoint, error);
        return nil;
    }
    if (fetchedObjects.count > 0)
        return [fetchedObjects objectAtIndex:0];
    return nil;
}

+ (void)checkpoint:(NSString*)checkpoint {
    TRStatistics* mgr = [TRStatistics manager];
    TRCheckpointEvent* ev = [mgr findCheckpointEvent:checkpoint];

    if (!ev) {
        TRCheckpointEvent* e = [NSEntityDescription
          insertNewObjectForEntityForName:@"TRCheckpointEvent"
          inManagedObjectContext:mgr.managedObjectContext];
        e.timestamp = [NSDate date];
        e.code = checkpoint;
        NSError* error;
        [mgr.managedObjectContext save:&error];
        if (error)
            DDLogError(@"failed to save checkpoint for %@: %@", checkpoint, error);
    }
}

+ (void)crashedOnPreviousRun {
    TRStatistics* mgr = [TRStatistics manager];
    TRCrashInfo* c = [NSEntityDescription
      insertNewObjectForEntityForName:@"TRCrashInfo"
      inManagedObjectContext:mgr.managedObjectContext];

    c.timestamp = [NSDate date];

    NSError* error = nil;
    if (![mgr.managedObjectContext save:&error]) {
        DDLogError(@"failed to save TRCrashInfo: %@", [error localizedDescription]);
    }
}

+ (int)crashCount {
    TRStatistics* mgr = [TRStatistics manager];
    NSFetchRequest* request = [NSFetchRequest fetchRequestWithEntityName:@"TRCrashInfo"];
    [request setIncludesSubentities:NO];
    NSError* error;
    NSUInteger count = [mgr.managedObjectContext countForFetchRequest:request error:&error];
    if (count == NSNotFound)
        return 0;
    if (error)
        DDLogError(@"failed to fetch TRCrashInfo count: %@", [error localizedDescription]);
    return (int)count;
}

+ (NSString*)userEmailAddress {
    TRStatistics* mgr = [TRStatistics manager];
    TRUploadState* st = [mgr mostRecentUploadState];
    if (st)
        return st.user_email_address;
    return nil;
}

+ (void)setUserEmailAddress:(NSString*)email {
    TRStatistics* mgr = [TRStatistics manager];
    TRUploadState* st = [mgr mostRecentUploadState];
    if (st && ![st.user_email_address isEqualToString:email]) {
        st.user_email_address = email;
        NSError* error = nil;
        [mgr.managedObjectContext save:&error];
        if (error)
            DDLogError(@"failed to save user email address");
    }
}

+ (NSString*)checkpointNameForUnlockedRecipeCode:(NSString*)recipeCode {
    return [unlockCodePrefix stringByAppendingString:recipeCode];
}

+ (LockedRecipeCodeType)isRecipeCodeLocked:(NSString*)recipeCode {
    TRStatistics* mgr = [TRStatistics manager];
    NSNumber* lockedType = [mgr.lockedTypes objectForKey:recipeCode];
    if (!lockedType)
        return LockedRecipeCodeNotLocked;
    return (LockedRecipeCodeType)lockedType.integerValue;
}

+ (void)unlockRecipeCode:(NSString*)recipeCode {
    [[TRStatistics manager].lockedTypes removeObjectForKey:recipeCode];
    [TRStatistics checkpoint:[TRStatistics checkpointNameForUnlockedRecipeCode:recipeCode]];
}

+ (void)unlockRecipeCodeAndFollowURL:(NSString*)recipeCode {
    NSURL* url = [TRStatistics urlForUnlockingRecipeCode:recipeCode];
    if (url) {
        DDLogInfo(@"following url %@", url);
        [TRStatistics unlockRecipeCode:recipeCode];
        [[UIApplication sharedApplication] openURL:url];
    } else {
        DDLogInfo(@"couldn't follow url: %@", url);
    }
}

+ (NSURL*)urlForUnlockingRecipeCode:(NSString*)recipeCode {
    NSArray* urls = [[TRStatistics manager].lockedCodes objectForKey:recipeCode];

    if (urls.count == 1) {
        NSString* u = [urls objectAtIndex:0];
        DDLogInfo(@"cached urlForUnlocking %@ is %@", recipeCode, u);
        return [NSURL URLWithString:u];
    }

    if (urls == nil) {
        DDLogError(@"no URLs at all for unlocking recipe code %@", recipeCode);
        return nil;
    }
    for (NSString* u in urls) {
        NSURL* url = [NSURL URLWithString:u];
        if ([[UIApplication sharedApplication] canOpenURL:url]) {
            DDLogInfo(@"urlForUnlocking %@ is %@", recipeCode, url);
            [[TRStatistics manager].lockedCodes setObject:@[u] forKey:recipeCode];
            return url;
        }
    }
    DDLogError(@"no URL found for unlocking recipe code %@", recipeCode);
    return nil;
}

- (void)initializeMagicWeightForCode:(NSString*)code weight:(NSNumber*)weight {
    NSFetchRequest* fetchRequest = [self.managedObjectModel
      fetchRequestFromTemplateWithName:@"fetchMagicWeightForCode"
      substitutionVariables:[NSDictionary dictionaryWithObjectsAndKeys:
        code, @"RECIPE_CODE", nil]];
    NSAssert(fetchRequest, WHERE);

    NSError* error = nil;
    NSArray* fetchedObjects = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (fetchedObjects.count < 1) {
        TRMagicWeight* w = [NSEntityDescription
          insertNewObjectForEntityForName:@"TRMagicWeight"
          inManagedObjectContext:self.managedObjectContext];
        w.recipe_code = code;
        w.weight = weight;
        NSError* error = nil;
        [self.managedObjectContext save:&error];
        if (error)
            DDLogError(@"failed to initialize magic weight for %@: %@", code, error);
    }
}

- (BOOL)codeIsUnlocked:(NSString*)code {
    // TODO: store filter unlocked state in core data
    return NO;
}

- (void)initializeBuiltinCode:(NSString*)code values:(NSDictionary*)values {
    [self insertOrUpdateRecipeForCode:code name:[values objectForKey:@"name"] builtin:YES];
    [self initializeMagicWeightForCode:code weight:[values objectForKey:@"weight"]];

    NSNumber* lockedType = [values objectForKey:@"lockedType"];
    if (lockedType) {
        [self.lockableCodes addObject:code];
        NSString* checkpointCode = [TRStatistics checkpointNameForUnlockedRecipeCode:code];
        if (![self findCheckpointEvent:checkpointCode]) {
            [self.lockedTypes setObject:lockedType forKey:code];
            NSArray* urlsForUnlock = [values objectForKey:@"urlsForUnlock"];
            if (![self codeIsUnlocked:code])
                [self.lockedCodes setObject:urlsForUnlock forKey:code];
        }
    }
}

- (NSString*)insertOrUpdateRecipeForCode:(NSString*)code name:(NSString*)name
  builtin:(BOOL)builtin
{
    TRNamedRecipe* recipe = [self fetchRecipeForCode:code];
    if (!builtin && recipe && recipe.builtin.boolValue) {
        [NSException raise:@"StatisticsError" format:@"Can't rename builtin recipe"];
    }

    NSString* oldName = nil;

    if (!recipe) {
        recipe = [NSEntityDescription
          insertNewObjectForEntityForName:@"TRNamedRecipe"
          inManagedObjectContext:self.managedObjectContext];
        recipe.recipe_code = code;
    } else {
        oldName = recipe.recipe_name;
    }

    // inside conditionals to avoid needlessly setting hasChanged flag
    if (![recipe.recipe_name isEqual:name])
        recipe.recipe_name = name;
    if (recipe.builtin.boolValue != builtin)
        recipe.builtin = [NSNumber numberWithBool:builtin];

    NSError* error = nil;
    if (![self.managedObjectContext save:&error])
        DDLogError(@"failed to save TRNamedRecipe: %@", [error localizedDescription]);

    return oldName;
}

- (TRNamedRecipe*) fetchRecipeForCode:(NSString*)code {
    NSFetchRequest* fetchRequest = [self.managedObjectModel
      fetchRequestFromTemplateWithName:@"fetchNamedRecipeForCode"
      substitutionVariables:[NSDictionary dictionaryWithObjectsAndKeys:
        code, @"RECIPE_CODE", nil]];
    NSAssert(fetchRequest, WHERE);
    NSEntityDescription* entity = [NSEntityDescription entityForName:@"TRNamedRecipe"
      inManagedObjectContext:self.managedObjectContext];
    NSAssert(entity, WHERE);
    [fetchRequest setEntity:entity];

    NSError* error = nil;
    NSArray* fetchedObjects = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (fetchedObjects.count == 1)
        return (TRNamedRecipe*)[fetchedObjects objectAtIndex:0];
    else if (fetchedObjects.count > 1)
        DDLogInfo(@"found %zd recipes for code %@", fetchedObjects.count, code);
    else
        DDLogVerbose(@"no recipe for code \"%@\" (%@)", code, error);
    return nil;
}

- (NSArray*) fetchAllUserRecipes {
    NSFetchRequest* fetchRequest = [[self.managedObjectModel
      fetchRequestTemplateForName:@"fetchAllUserRecipes"] copy];
    NSAssert(fetchRequest, WHERE);

    // Can't set sort descriptors on named fetch request :-(

    NSError* error = nil;
    NSArray* fetchedObjects = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (error)
        [NSException raise:@"StatisticsError" format:@"%@", error];

    return [fetchedObjects sortedArrayUsingComparator:^(TRNamedRecipe* r1, TRNamedRecipe* r2) {
        return [r1.recipe_name compare:r2.recipe_name];
    }];
}

- (NSArray*) fetchHistoryWithLimit:(NSInteger)limit {
    NSFetchRequest* fetchRequest =
      [NSFetchRequest fetchRequestWithEntityName:@"TRUsageHistory"];
    NSAssert(fetchRequest, WHERE);
    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:
      [[NSSortDescriptor alloc] initWithKey:@"timestamp" ascending:NO]]];

    NSMutableSet* codes = [[NSMutableSet alloc] init];
    NSMutableArray* result = [[NSMutableArray alloc] init];
    NSError* error = nil;
    NSArray* fetchedObjects =
      [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (error)
        [NSException raise:@"StatisticsError" format:@"%@", error];

    for (TRUsageHistory* h in fetchedObjects) {
        if (![codes containsObject:h.recipe_code]) {
            [codes addObject:h.recipe_code];
            [result addObject:h];
            if (codes.count >= limit)
                break;
        }
    }
    return result;
}

- (NSArray*) fetchMagicWithLimit:(NSInteger)limit {
    NSFetchRequest* allMagic = [NSFetchRequest fetchRequestWithEntityName:@"TRMagicWeight"];
    NSAssert(allMagic, WHERE);

    [allMagic setSortDescriptors:[NSArray arrayWithObject:
      [[NSSortDescriptor alloc] initWithKey:@"weight" ascending:NO]]];

    NSError* error = nil;
    NSArray* fetchedObjects = [self.managedObjectContext executeFetchRequest:allMagic error:&error];
    if (error)
        [NSException raise:@"StatisticsError" format:@"%@", error];

    NSMutableArray* result = [[NSMutableArray alloc] init];
    [[fetchedObjects subarrayWithRange:NSMakeRange(0, MIN(limit, fetchedObjects.count))]
      enumerateObjectsUsingBlock:^(TRMagicWeight* w, NSUInteger idx, BOOL *stop){
        if (w.weight.floatValue > 0.000001)
            [result addObject:w.recipe_code];
    }];

    return result;
}

- (void)initialConditionsFixup {
    NSArray* m = [self fetchMagicWithLimit:1];
    if (m.count == 0)
        return;
    NSString* w = [m objectAtIndex:0];
    [TRStatistics recipeWasUsed:w];
}

+ (NSString*)humanFriendlyDateDifferenceBetween:(NSDate*)d1 and:(NSDate*)d2 {
    NSTimeInterval interval = [d2 timeIntervalSinceDate:d1];
    if (interval < 10.0) {
        return @"just now";
    } if (interval < 90.0) {
        return [NSString stringWithFormat:@"%.0f seconds ago", interval];
    } if (interval < 59.5 * 60.0) {
        return [NSString stringWithFormat:@"%.0f minutes ago", interval / 60.0];
    } if (interval < 23.5 * 60.0 * 60.0) {
        return [NSString stringWithFormat:@"%.0f hours ago", interval / 3600.0];
    }

    NSCalendar* cal = [NSCalendar currentCalendar];
    NSDateComponents* components =
      [cal components:(NSHourCalendarUnit|NSMinuteCalendarUnit|NSSecondCalendarUnit) fromDate:d2];

    components.hour = -components.hour;
    components.minute = -components.minute;
    components.second = -components.second;
    NSDate* today = [cal dateByAddingComponents:components toDate:d2 options:0];

    components.hour = -24;
    components.minute = 0;
    components.second = 0;
    NSDate* yesterday = [cal dateByAddingComponents:components toDate:today options:0];

    if ([d1 timeIntervalSinceDate:yesterday] >= 0.0)
        return @"yesterday";

    components.hour = 0;
    components.day = -6;
    NSDate* aWeekAgo = [cal dateByAddingComponents:components toDate:today options:0];

    if ([d1 timeIntervalSinceDate:aWeekAgo] >= 0.0) {
        NSDateFormatter* fmt = [[NSDateFormatter alloc] init];
        [fmt setDateFormat:[NSDateFormatter dateFormatFromTemplate:NSLocalizedString(@"EEEhma", nil) options:0 locale:[NSLocale currentLocale]]];
        return [fmt stringFromDate:d1];
    }

    NSDateFormatter* fmt = [[NSDateFormatter alloc] init];
    [fmt setDateFormat:[NSDateFormatter dateFormatFromTemplate:NSLocalizedString(@"dMMM", nil) options:0 locale:[NSLocale currentLocale]]];
    return [fmt stringFromDate:d1];
}

- (NSString*)historyDescriptionForCode:(NSString*)code {
    NSFetchRequest* fetchRequest =
      [NSFetchRequest fetchRequestWithEntityName:@"TRUsageHistory"];
    NSAssert(fetchRequest, WHERE);
    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:
      [[NSSortDescriptor alloc] initWithKey:@"timestamp" ascending:NO]]];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"recipe_code == %@", code]];

    NSError* error = nil;
    NSArray* fetchedObjects = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (error)
        [NSException raise:@"StatisticsError" format:@"%@", error];
    if (fetchedObjects.count > 0) {
        TRUsageHistory* h = [fetchedObjects objectAtIndex:0];
        NSAssert([h.recipe_code isEqualToString:code], @"%@ == %@", h.recipe_code, code);
        return [TRStatistics humanFriendlyDateDifferenceBetween:h.timestamp and:[NSDate date]];
    }
    return @"";
}

+ (NSString*)recipeCode:(NSString*)code assignedName:(NSString*)name {
    NSString* oldName = nil;
    @try {
        DDLogInfo(@"recipeCode %@ assigned name \"%@\"", code, name);
        TRRecipeCodeParser* par = [[TRRecipeCodeParser alloc] initWithCode:code];
        [par tree];   // attempt to parse recipe code
        oldName = [[TRStatistics manager] insertOrUpdateRecipeForCode:code name:name builtin:NO];
        [TRStatistics recipeWasUsed:code];
    }
    @catch (NSException* x) {
        // don't populate database with invalid recipes!
        DDLogError(@"failed to parse recipe \"%@\": %@", code, x);
    }
    return oldName;
}

+ (NSString*)importRecipeFromURL:(NSURL*)url {
    DDLogWarn(@"importRecipeFromURL %@", url);
    NSString* recipeName = nil;
    NSArray* p = url.pathComponents;
    if (p.count == 3 && [[p objectAtIndex:0] isEqualToString:@"/"]) {
        recipeName = [p objectAtIndex:2];
        [TRStatistics recipeCode:[p objectAtIndex:1] assignedName:recipeName];
    } else {
        DDLogError(@"invalid url: %@", url);
    }
    return recipeName;
}

+ (NSURL*) urlWithRecipeCode:(NSString*)code named:(NSString*)name {
    return [[NSURL alloc] initWithScheme:@"pictapgo" host:@"r" path:
      [NSString stringWithFormat:@"/%@/%@", code, name]];
}

+ (NSString*) nameForCode:(NSString*)code {
    return [TRStatistics nameForCode:code includeHistory:YES];
}

+ (NSString*) nameForCode:(NSString*)code includeHistory:(BOOL)includeHistory {
    TRNamedRecipe* recipe = [[TRStatistics manager] fetchRecipeForCode:code];
    if (recipe)
        return recipe.recipe_name;
    if (includeHistory)
        return [[TRStatistics manager] historyDescriptionForCode:code];
    return nil;
}

+ (void) deleteNameForCode:(NSString*)code {
    TRStatistics* mgr = [TRStatistics manager];
    TRNamedRecipe* recipe = [mgr fetchRecipeForCode:code];
    if (recipe && !recipe.builtin.boolValue) {
        DDLogInfo(@"deleting recipe \"%@\" for code \"%@\"", recipe.recipe_name, code);
        [mgr.managedObjectContext deleteObject:recipe];
        NSError* error = nil;
        [mgr.managedObjectContext save:&error];
        if (error)
            DDLogError(@"failed to delete recipe for code %@", code);
    }
}

+ (void) updateMagicWeightsForCode:(NSString*)recipeCode {
    NSArray* styletCodes = [TRRecipe styletsInRecipeCode:recipeCode];
    if (styletCodes.count < 1)
        return;

    TRStatistics* mgr = [TRStatistics manager];
    NSFetchRequest* allWeights =
      [NSFetchRequest fetchRequestWithEntityName:@"TRMagicWeight"];
    NSAssert(allWeights, WHERE);

    NSError* error = nil;
    NSArray* fetchedObjects = [mgr.managedObjectContext
      executeFetchRequest:allWeights error:&error];
    if (error) {
        DDLogError(@"failed to fetch magic weights");
        return;
    }

    for (TRMagicWeight* w in fetchedObjects) {
        const float before = w.weight.floatValue;
        if ([styletCodes containsObject:w.recipe_code]) {
            const float after = MIN(1.0, 0.1 + before * 0.9);
            DDLogVerbose(@"update weight for %@ from %f to %f", w.recipe_code, before, after);
            w.weight = [NSNumber numberWithFloat:after];
        } else if (before > 0.0) {
            w.weight = [NSNumber numberWithFloat:before * 0.95];
        } else if (before < 0.0) {
            w.weight = [NSNumber numberWithFloat:0.0];
        }
    }

    [mgr.managedObjectContext save:&error];
    if (error)
        DDLogError(@"failed to save changes in updateMagicWeightsForCode");
}

+ (NSArray*) namedRecipeList {
    return [[TRStatistics manager] fetchAllUserRecipes];
}

+ (NSArray*) usageHistoryListWithLimit:(NSInteger)limit {
    TRStatistics* mgr = [TRStatistics manager];
    NSArray* h = [mgr fetchHistoryWithLimit:limit];
    if (h.count == 0) {
        [mgr initialConditionsFixup];
        h = [mgr fetchHistoryWithLimit:limit];
    }
    return h;
}

+ (NSArray*) magicListWithLimit:(NSInteger)limit {
    return [[TRStatistics manager] fetchMagicWithLimit:limit];
}

+ (void)populateWithTestData:(PopulateBlock)populateBlock {
    TRStatistics* mgr = [TRStatistics manager];
    populateBlock(mgr.managedObjectModel, mgr.persistentStoreCoordinator, mgr.managedObjectContext);
}

#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection*)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge*)challenge {
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
        if ([self.trustedHosts containsObject:challenge.protectionSpace.host])
            [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];

    [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}

- (NSCachedURLResponse*)connection:(NSURLConnection*)connection willCacheResponse:(NSCachedURLResponse*)cachedResponse {
    // Don't cache any responses
    return nil;
}

- (void)connection:(NSURLConnection*)connection didReceiveData:(NSData*)data {
    DDLogVerbose(@"stats received %zd bytes", data.length);
}

- (void)connection:(NSURLConnection*)connection didFailWithError:(NSError*)error {
    DDLogError(@"stats failed with error: %@", error);
}

- (void)connection:(NSURLConnection*)connection didReceiveResponse:(NSURLResponse*)response {
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse* rsp = (NSHTTPURLResponse*)response;
        [self performSelectorOnMainThread:@selector(uploadFinished:) withObject:rsp waitUntilDone:NO];
    } else {
        DDLogError(@"stats received response: %@", response);
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection*)connection {
}

@end
