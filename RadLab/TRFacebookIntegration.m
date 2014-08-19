//
//  TRFacebookIntegration.m
//  RadLab
//
//  Created by Tim Ruddick on 7/16/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//
#ifdef USE_FACEBOOKINTEGRATION

#import "TRFacebookIntegration.h"
#import "DDLog.h"
#import <FacebookSDK/FacebookSDK.h>
#import <FacebookSDK/FBSession.h>

static const int ddLogLevel = LOG_LEVEL_INFO;

typedef enum {
    UNKNOWN = 0,    // initial state
    PROCESSING,     // establishing connection to FB, running FQL query, etc
    READY,          // check complete: "liked" vars now valid
    BLOCKED         // cannot connect to FB, for whatever reason
  } CheckState;

@interface TRFacebookIntegrationState : NSObject {
NSConditionLock* checking;
}
@property BOOL likedPicTapGo;
@property BOOL likedGetTotallyRad;
@end

@implementation TRFacebookIntegrationState
- (id)init {
    self = [super init];
    if (self) {
        checking = [[NSConditionLock alloc] initWithCondition:UNKNOWN];
    }
    return self;
}

// select uid, page_id from page_fan where uid=594392215 and (page_id=169305903816 or page_id=558142237548493)
// select uid, page_id from page_fan where uid in (select uid from user where username='truddick') and (page_id=169305903816 or page_id=558142237548493)
// select uid, page_id from page_fan where uid=me() and (page_id=169305903816 or page_id=558142237548493)

- (void)facebookCheckPageLikes {
    NSString* fql = [NSString stringWithFormat:
      @"select uid, page_id from page_fan where uid=me() and (page_id=%@ or page_id=%@)",
      FacebookPageIdPicTapGo, FacebookPageIdGetTotallyRad];
    NSDictionary* params = @{@"q": fql};
    [FBRequestConnection startWithGraphPath:@"/fql" parameters:params
      HTTPMethod:@"GET" completionHandler:^(FBRequestConnection* connection, id result, NSError* error){
        if (error) {
            DDLogInfo(@"FQL Error: %@", [error localizedDescription]);
            [[FBSession activeSession] closeAndClearTokenInformation];
        } else {
            DDLogInfo(@"FQL Result: %@", result);
            [[FBSession activeSession] closeAndClearTokenInformation];
        }
      }];
}

- (NSString*)fbSessionStateString:(FBSessionState)status {
    switch (status) {
    FBSessionStateCreated: return @"Created";
    FBSessionStateCreatedTokenLoaded: return @"CreatedTokenLoaded";
    FBSessionStateCreatedOpening: return @"CreatedOpening";
    FBSessionStateOpen: return @"Open";
    FBSessionStateOpenTokenExtended: return @"OpenTokenExtended";
    FBSessionStateClosedLoginFailed: return @"ClosedLoginFailed";
    FBSessionStateClosed: return @"Closed";
    default: return [NSString stringWithFormat:@"unknown-%#x", status];
    }
}

- (void)facebookOpenSession {
    BOOL openedSynchronously = [FBSession openActiveSessionWithReadPermissions:@[@"user_likes"] allowLoginUI:YES
      completionHandler:^(FBSession* session, FBSessionState status, NSError* error){
        if (error) {
            DDLogInfo(@"FB openActiveSessionWithReadPermissions failed: %@", [error localizedDescription]);
            [[FBSession activeSession] closeAndClearTokenInformation];
        } else {
            DDLogInfo(@"FB openActiveSessionWithReadPermissions succeeded: %@", [self fbSessionStateString:status]);
            [self facebookCheckPageLikes];
        }
    }];
    if (openedSynchronously)
        [self facebookCheckPageLikes];
}

- (void)idempotentRunQueries {
    if ([checking tryLockWhenCondition:UNKNOWN]) {
        [checking unlockWithCondition:PROCESSING];
        [self facebookOpenSession];
    }
}

@end

@implementation TRFacebookIntegration

+ (TRFacebookIntegrationState*)state {
    static dispatch_once_t once;
    static TRFacebookIntegrationState* state;
    dispatch_once(&once, ^(){
        state = [[TRFacebookIntegrationState alloc] init];
    });
    return state;
}

+ (void)notifyAppStarted {
    NSString* fbAppID = [FBSession defaultAppID];
    [FBSettings publishInstall:fbAppID withHandler:^(FBGraphObject* response, NSError* error) {
        if (error)
            DDLogWarn(@"Facebook response %@ (%@)", response, error);
    }];
}

+ (BOOL)isPageLiked_PicTapGo {
    TRFacebookIntegrationState* state = [TRFacebookIntegration state];
    [state idempotentRunQueries];
    return state.likedPicTapGo;
}

+ (BOOL)isPageLiked_GetTotallyRad {
    TRFacebookIntegrationState* state = [TRFacebookIntegration state];
    [state idempotentRunQueries];
    return state.likedGetTotallyRad;
}

+ (BOOL)isPageLiked_Any {
    TRFacebookIntegrationState* state = [TRFacebookIntegration state];
    [state idempotentRunQueries];
    return state.likedGetTotallyRad || state.likedPicTapGo;
}
@end

#endif  // USE_FACEBOOKINTEGRATION