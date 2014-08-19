//
//  TRUsageHistory_TRJSONSerialization.h
//  RadLab
//
//  Created by Tim Ruddick on 2/15/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import "TRJSONSerialization.h"

NSArray* representationForJSON(NSArray* input) {
    NSMutableArray* result = [[NSMutableArray alloc] initWithCapacity:input.count];
    for (id i in input)
        [result addObject:[i representationForJSON]];
    return result;
}

@implementation TRUsageHistory (JSONConvert)
- (id)representationForJSON {
    return [NSArray arrayWithObjects:
      [NSNumber numberWithLongLong:[self.timestamp timeIntervalSince1970]],
      self.recipe_code,
      nil];
}
@end

@implementation TRShareHistory (JSONConvert)
- (id)representationForJSON {
    return [NSArray arrayWithObjects:
      [NSNumber numberWithLongLong:[self.timestamp timeIntervalSince1970]],
      self.share_destination,
      self.recipe_code,
      nil];
}
@end

@implementation TRNamedRecipe (JSONConvert)
- (id)representationForJSON {
    return [NSArray arrayWithObjects:
      self.builtin,
      self.recipe_code,
      self.recipe_name,
      nil];
}
@end

@implementation TRMagicWeight (JSONConvert)
- (id)representationForJSON {
    return [NSArray arrayWithObjects:
      self.recipe_code,
      self.weight,
      nil];
}
@end

@implementation TRCheckpointEvent (JSONConvert)
- (id)representationForJSON {
    return [NSArray arrayWithObjects:
      [NSNumber numberWithLongLong:[self.timestamp timeIntervalSince1970]],
      self.code,
      nil];
}
@end

@implementation TRCrashInfo (JSONConvert)
- (id)representationForJSON {
    return [NSArray arrayWithObjects:
      [NSNumber numberWithLongLong:[self.timestamp timeIntervalSince1970]],
      nil];
}
@end
