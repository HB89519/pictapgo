//
//  TRStatistics.h
//  Stylet
//
//  Created by Tim Ruddick on 1/21/13.
//  Copyright (c) 2013 Totally Rad!. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

#import "TRUsageHistory.h"
#import "TRShareHistory.h"
#import "TRNamedRecipe.h"

static NSString* const TRCheckpointUsedCamera = @"Cam";
static NSString* const TRCheckpointUsedPasteboard = @"PB";
static NSString* const TRCheckpointUsedAlbumView = @"Alb";
static NSString* const TRCheckpointUsedReset = @"Reset";
static NSString* const TRCheckpointUsedStrength = @"Str";
static NSString* const TRCheckpointUsedUndo = @"Undo";
static NSString* const TRCheckpointUsedRedo = @"Redo";
static NSString* const TRCheckpointCopiedRecipeToClipboard = @"RcpClip";
static NSString* const TRCheckpointStackedTwo = @"Stk2";
static NSString* const TRCheckpointStackedFive = @"Stk5";
static NSString* const TRCheckpointSavedToClipboard = @"Clip";
static NSString* const TRCheckpointCancelledShareIgram = @"CncIg";
static NSString* const TRCheckpointCancelledShareFacebook = @"CncFb";
static NSString* const TRCheckpointCancelledShareTwitter = @"CncTw";

typedef enum {
    LockedRecipeCodeNotLocked = 0,
    LockedRecipeCodeFacebook,
    LockedRecipeCodeInstagram,
    LockedRecipeCodeTwitter,
    LockedRecipeCodeMailingList
} LockedRecipeCodeType;

@interface TRStatistics: NSObject

+ (void) prepopulate;
+ (void) ping;
+ (NSUUID*) deviceIdentifier; // return a unique device identifier

+ (void) resetMagic;
+ (void) deleteAllHistory;
+ (void) deleteAllNames;
+ (void) resetUnlockedFilters;

typedef void (^PopulateBlock)(NSManagedObjectModel* managedObjectModel,
  NSPersistentStoreCoordinator* persistentStoreCoordinator,
  NSManagedObjectContext* managedObjectContext);
+ (void) populateWithTestData:(PopulateBlock)populateBlock;

+ (void) recipeWasUsed:(NSString*)recipeCode;
+ (void) imageWasShared:(NSString*)destination usingRecipe:(NSString*)recipeCode;
+ (NSString*) recipeCode:(NSString*)recipeCode assignedName:(NSString*)name; // returns the old name
+ (NSString*) nameForCode:(NSString*)recipeCode;
+ (NSString*) nameForCode:(NSString*)recipeCode includeHistory:(BOOL)history;
+ (void) deleteNameForCode:(NSString*)recipeCode;
+ (NSString*) importRecipeFromURL:(NSURL*)url;
+ (NSURL*) urlWithRecipeCode:(NSString*)code named:(NSString*)name;
+ (void) updateMagicWeightsForCode:(NSString*)recipeCode;

+ (void) checkpoint:(NSString*)checkpoint;

+ (void) crashedOnPreviousRun;
+ (int) crashCount;

+ (NSString*) userEmailAddress;
+ (void) setUserEmailAddress:(NSString*)email;

+ (LockedRecipeCodeType) isRecipeCodeLocked:(NSString*)recipeCode;
+ (void) unlockRecipeCodeAndFollowURL:(NSString*)recipeCode;

// returns list of TRNamedRecipe objects
+ (NSArray*) namedRecipeList;

// returns 'limit' most recent objects of TRUsageHistory, omitting duplicates
+ (NSArray*) usageHistoryListWithLimit:(NSInteger)limit;

// return 'limit' items to fill the "Magic" (My Style) folder
+ (NSArray*) magicListWithLimit:(NSInteger)limit;
@end
