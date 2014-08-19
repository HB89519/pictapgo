//
//  TRStatisticsTest.m
//  RadLab
//
//  Created by Tim Ruddick on 1/30/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import "TRStatisticsTest.h"
#import "TRStatistics.h"
#import "TRUsageHistory.h"

@implementation TRStatisticsTest

- (void)deleteSQLiteStore {
    NSFileManager* fm = [NSFileManager defaultManager];
    NSError* error = nil;
    [fm removeItemAtPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"TR.sqlite"] error:&error];
}

- (void)setUp {
    //[self deleteSQLiteStore];

    [TRStatistics prepopulate];

    [TRStatistics populateWithTestData:^(NSManagedObjectModel* model, NSPersistentStoreCoordinator* coord, NSManagedObjectContext* ctx){
        NSFetchRequest* fetchRequest =
          [NSFetchRequest fetchRequestWithEntityName:@"TRNamedRecipe"];
        NSError* error = nil;
        NSArray* fetchedObjects = [ctx executeFetchRequest:fetchRequest error:&error];
        if (error)
            [NSException raise:@"StatisticsError" format:@"%@", error];
        NSArray* allRecipes = [NSArray arrayWithArray:fetchedObjects];

        NSInteger when = 0;
        unsigned int timeSeed = 12345;
        unsigned int codeSeed = 12345;

        for (int i = 0; i < 2000; ++i) {
            TRUsageHistory* h = [NSEntityDescription
              insertNewObjectForEntityForName:@"TRUsageHistory"
              inManagedObjectContext:ctx];
            when -= rand_r(&timeSeed) % 10;
            when -= rand_r(&timeSeed) % 60;
            when -= rand_r(&timeSeed) % 900;
            when -= rand_r(&timeSeed) % 3600;
            when -= rand_r(&timeSeed) % 86400;
            h.timestamp = [NSDate dateWithTimeIntervalSinceNow:when];
            int weight = rand_r(&codeSeed) % 8192;
            weight += rand_r(&codeSeed) % 4096;
            weight += rand_r(&codeSeed) % 2048;
            weight += rand_r(&codeSeed) % 1024;
            float fweight = weight / (8192.0 + 4096.0 + 2048.0 + 1024.0);
            int codeObj = fweight * allRecipes.count;
            h.recipe_code = ((TRNamedRecipe*)[allRecipes objectAtIndex:codeObj]).recipe_code;
        }

        error = nil;
        if (![ctx save:&error]) {
            NSLog(@"failed to save TRUsageHistory: %@", [error localizedDescription]);
        }
    }];
}

- (void)tearDown {
    //[self deleteSQLiteStore];
}

- (void)test01 {
    NSArray* magic = [TRStatistics magicListWithLimit:9];
    NSArray* goldenList = [NSArray arrayWithObjects:
      @"Sk", @"Fc", @"V", @"Bt", @"S", @"W", @"Mg", @"Sn", @"Pr",
      nil];
    for (NSUInteger i = 0; i < magic.count; ++i) {
        NSString* r1 = [magic objectAtIndex:i];
        NSString* r2 = [goldenList objectAtIndex:i];
        STAssertTrue([r1 isEqual:r2],
          @"unexpected magic entry %d \"%@\" (expected \"%@\")", i, r1, r2);
    }
}

- (void)test02 {
    [TRStatistics deleteAllHistory];
    NSArray* history = [TRStatistics usageHistoryListWithLimit:9];
    STAssertEquals(history.count, 0, @"expected history to be empty");
}

@end
