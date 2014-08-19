//
//  CIContext+SingleThreadedRendering.m
//  RadLab
//
//  Created by Tim Ruddick on 3/14/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import "CIContext+SingleThreadedRendering.h"
#import "TRHelper.h"

static const int ddLogLevel = LOG_LEVEL_INFO;

/**
This method is intended to be the focal point for all rendering from CIFilter
into CGImage.  This makes it easier to find such callers in the codebase, and
makes it easier to instrument potentially crashy usage of CI->CG.

One idea I considered was single-threading use of CI via a mutex around the
all to createCGImage.  It is unclear whether this helps anything, and it
definitely makes things slower.  Here are some stats from my iPhone 4S:

# WITH the mutex: 5.171 seconds to render all thumbnails
tim-1397: ./timing-mining.pl timing2
11:07:39:768 40059.768
11:07:44:147 40064.147 -> 4.379
11:07:58:382 40078.382
11:08:03:566 40083.566 -> 5.184
11:08:10:243 40090.243
11:08:15:424 40095.424 -> 5.181
11:08:19:924 40099.924
11:08:24:950 40104.950 -> 5.026
11:08:29:462 40109.462
11:08:35:343 40115.343 -> 5.881
11:08:42:352 40122.352
11:08:47:729 40127.729 -> 5.377
5.171

# WITHOUT the mutex: 3.998 seconds to render all thumbnails
tim-1399: ./timing-mining.pl timing3
11:22:30:372 40950.372
11:22:33:739 40953.739 -> 3.367
11:22:38:316 40958.316
11:22:42:032 40962.032 -> 3.716
11:22:45:794 40965.794
11:22:49:553 40969.553 -> 3.759
11:22:53:184 40973.184
11:22:56:823 40976.823 -> 3.639
11:23:01:518 40981.518
11:23:05:297 40985.297 -> 3.779
11:23:08:839 40988.839
11:23:12:281 40992.281 -> 3.442
11:23:17:136 40997.136
11:23:21:475 41001.475 -> 4.339
11:23:25:700 41005.700
11:23:31:647 41011.647 -> 5.947
3.998
*/

@implementation CIContext (SingleThreadedRendering)

typedef enum { IDLE, RUNNING, BLOCKED, BLOCKED_AND_RUNNING } CoreImageLockState;

+ (NSConditionLock*) coreImageLock {
    static NSConditionLock* lock;
    static dispatch_once_t once;
    dispatch_once(&once, ^(){
        lock = [[NSConditionLock alloc] initWithCondition:IDLE];
    });
    return lock;
}

+ (void) coreImageUsageStart {
    NSConditionLock* lock = [CIContext coreImageLock];
    if ([NSThread isMainThread]) {
        BOOL locked = NO;
        for (int attempts = 0; !locked && attempts < 10; ++attempts) {
            locked = [lock lockWhenCondition:IDLE beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
        }
        if (!locked) {
            DDLogError(@"Main thread coreImageUsageStart failed to acquire lock in IDLE state");
            [lock lock];
            DDLogError(@"Main thread coreImageUsageStart acquired lock in state %zd", lock.condition);
        }
    } else {
        [lock lockWhenCondition:IDLE];
    }
    [lock unlockWithCondition:RUNNING];
}

+ (void) coreImageUsageFinish {
    NSConditionLock* lock = [CIContext coreImageLock];
    [lock lock];
    if (lock.condition == RUNNING) {
        [lock unlockWithCondition:IDLE];
    } else if (lock.condition == BLOCKED_AND_RUNNING) {
        DDLogWarn(@"coreImageUsageFinished, move from BLOCKED_AND_RUNNING to BLOCKED");
        [lock unlockWithCondition:BLOCKED];
    } else {
        NSInteger condition = lock.condition;
        [lock unlock];
        DDLogWarn(@"coreImageUsageFinished, but state was %zd", condition);
    }
}

+ (void) blockCoreImageUsage {
    NSConditionLock* lock = [CIContext coreImageLock];
    [lock lock];
    DDLogWarn(@"blockCoreImageUsage, state=%zd", lock.condition);
    if (lock.condition == IDLE) {
        [lock unlockWithCondition:BLOCKED];
    } else if (lock.condition == RUNNING) {
        [lock unlockWithCondition:BLOCKED_AND_RUNNING];
    } else {
        NSInteger condition = lock.condition;
        [lock unlock];
        DDLogWarn(@"*** blockCoreImageUsage, but state was %zd", condition);
    }
}

+ (void) unblockCoreImageUsage {
    NSConditionLock* lock = [CIContext coreImageLock];
    [lock lock];
    DDLogWarn(@"unblockCoreImageUsage, state=%zd", lock.condition);
    if (lock.condition == BLOCKED) {
        [lock unlockWithCondition:IDLE];
    } else if (lock.condition == BLOCKED_AND_RUNNING) {
        [lock unlockWithCondition:RUNNING];
    } else {
        NSInteger condition = lock.condition;
        [lock unlock];
        DDLogWarn(@"*** unblockCoreImageUsage, but state was %zd", condition);
    }
}

- (CGImageRef)createCGImageMoreSafely:(CIImage*)inputImage fromRect:(CGRect)size CF_RETURNS_RETAINED {
    //[CIContext coreImageUsageStart];

    NSAssert(self, @"createCGImageMoreSafely self is nil");
    NSAssert(CFGetRetainCount((__bridge CFTypeRef)self) > 0, @"createCGImageMoreSafely CIContext retainCount is zero");
    NSAssert(CFGetRetainCount((__bridge CFTypeRef)inputImage) > 0, @"createCGImageMoreSafely inputImage retainCount is zero");
    CGImageRef cgImg = [self createCGImage:inputImage fromRect:size];

    //[CIContext coreImageUsageFinish];
    return cgImg;
}
@end
