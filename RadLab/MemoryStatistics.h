//
//  MemoryStatistics.h
//  RadLab
//
//  Created by Tim Ruddick on 2/26/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#ifndef RadLab_MemoryStatistics_h
#define RadLab_MemoryStatistics_h

#ifdef __cplusplus
extern "C" {
#endif

#ifdef CONFIGURATION_AppStore
static inline natural_t memoryBytesAvailable() { return 0; }
static inline natural_t memoryBytesInUse() { return 0; }
#else
natural_t memoryBytesAvailable();
natural_t memoryBytesInUse();
#endif

NSString* stringWithMemoryBytesAvailable();
NSString* stringWithMemoryBytesInUse();
NSString* stringWithMemoryInfo();

#ifdef __cplusplus
}
#endif

#endif
