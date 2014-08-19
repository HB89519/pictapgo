//
//  TRUsageHistory_TRJSONSerialization.h
//  RadLab
//
//  Created by Tim Ruddick on 2/15/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import "TRUsageHistory.h"
#import "TRShareHistory.h"
#import "TRNamedRecipe.h"
#import "TRMagicWeight.h"
#import "TRCheckpointEvent.h"
#import "TRCrashInfo.h"

@interface TRUsageHistory (JSONConvert)
- (id)representationForJSON;
@end

@interface TRShareHistory (JSONConvert)
- (id)representationForJSON;
@end

@interface TRNamedRecipe (JSONConvert)
- (id)representationForJSON;
@end

@interface TRMagicWeight (JSONConvert)
- (id)representationForJSON;
@end

@interface TRCheckpointEvent (JSONConvert)
- (id)representationForJSON;
@end

@interface TRCrashInfo (JSONConvert)
- (id)representationForJSON;
@end

// run representationForJSON on all elements of "objects" and return new
// array containing the results
NSArray* representationForJSON(NSArray* objects);

