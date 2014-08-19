//
//  AppSettings.m
//  RadLab
//
//  Created by Tim Ruddick on 2/7/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import "AppSettings.h"
#import "EditGridViewController.h"

static NSString* kEditViewInitialFolderKey = @"EditViewInitialFolder";
static NSString* kPermissionsCheckKey = @"PermissionsCheck";
static NSString* kVisitedPicScreenKey = @"VisitedPicScreen";
static NSString* kVisitedTapScreenKey = @"VisitedTapScreen";
static NSString* kVisited2ndTapScreenKey = @"Visited2ndTapScreen";
static NSString* kVisitedGoScreenKey = @"VisitedGoScreen";
static NSString* kAppliedTwoFiltersKey = @"AppliedTwoFilters";
static NSString* kUseSimpleBackgroundKey = @"UseSimpleBackground";

@implementation AppSettings

+ (AppSettings*)manager {
    static dispatch_once_t once;
    static AppSettings* appSettings = nil;
    dispatch_once(&once, ^{
        appSettings = [[AppSettings alloc] init];
    });
    return appSettings;
}

+ (void)setup {
    // just instantiate the singleton, which takes care of the details
    [AppSettings manager];
}

+ (void)synchronize {
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (void)resetToDefaults {
    NSDictionary* defDict = [AppSettings defaultSettings];
    for (NSString* key in defDict) {
        [[NSUserDefaults standardUserDefaults] setObject:[defDict objectForKey:key] forKey:key];
    }
}

+ (NSDictionary *)defaultSettings {
    NSDictionary* appDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
                                 [NSNumber numberWithInt:kStyletFolderIDLibrary], kEditViewInitialFolderKey,
                                 [NSNumber numberWithInt:kPermissionsOK], kPermissionsCheckKey,
                                 @"NO", kVisitedPicScreenKey,
                                 @"NO", kVisitedTapScreenKey,
                                 @"NO", kVisited2ndTapScreenKey,
                                 @"NO", kVisitedGoScreenKey,
                                 @"NO", kAppliedTwoFiltersKey,
                                 @"NO", kUseSimpleBackgroundKey,
                                 nil];
    return appDefaults;
}

+ (void)resetHelpToDefaults {
    AppSettings* mgr = [AppSettings manager];
    mgr.permissionsCheck = kPermissionsOK;
    mgr.visitedPicScreen = NO;
    mgr.visitedTapScreen = NO;
    mgr.visited2ndTapScreen = NO;
    mgr.visitedGoScreen = NO;
    mgr.appliedTwoFilters = NO;
    mgr.useSimpleBackground = NO;
}

- (id)init {
    self = [super init];
    if (!self) return nil;

    [[NSUserDefaults standardUserDefaults] registerDefaults:[AppSettings defaultSettings]];

    return self;
}

- (NSInteger)editViewInitialFolder {
    return [[NSUserDefaults standardUserDefaults] integerForKey:kEditViewInitialFolderKey];
}

- (void)setEditViewInitialFolder:(NSInteger)val {
    [[NSUserDefaults standardUserDefaults] setInteger:val forKey:kEditViewInitialFolderKey];
}

- (BOOL)visitedPicScreen {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kVisitedPicScreenKey];
}

- (void)setVisitedPicScreen:(BOOL)bVisited {
    [[NSUserDefaults standardUserDefaults] setBool:bVisited forKey:kVisitedPicScreenKey];
}

- (BOOL)visitedTapScreen {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kVisitedTapScreenKey];
}

- (void)setVisitedTapScreen:(BOOL)bVisited {
    [[NSUserDefaults standardUserDefaults] setBool:bVisited forKey:kVisitedTapScreenKey];
}

- (BOOL)visited2ndTapScreen {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kVisited2ndTapScreenKey];
}

- (void)setVisited2ndTapScreen:(BOOL)bVisited {
    [[NSUserDefaults standardUserDefaults] setBool:bVisited forKey:kVisited2ndTapScreenKey];
}

- (BOOL)visitedGoScreen {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kVisitedGoScreenKey];
}

- (void)setVisitedGoScreen:(BOOL)bVisited {
    [[NSUserDefaults standardUserDefaults] setBool:bVisited forKey:kVisitedGoScreenKey];
}

- (PermissionsCheck)permissionsCheck {
    return (PermissionsCheck)[[NSUserDefaults standardUserDefaults] integerForKey:kPermissionsCheckKey];
}

- (void)setPermissionsCheck:(PermissionsCheck)permissionsCheck {
    [[NSUserDefaults standardUserDefaults] setInteger:permissionsCheck forKey:kPermissionsCheckKey];
}

- (BOOL)appliedTwoFilters {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kAppliedTwoFiltersKey];    
}

- (void)setAppliedTwoFilters:(BOOL)bApplied {
    [[NSUserDefaults standardUserDefaults] setBool:bApplied forKey:kAppliedTwoFiltersKey];
}

- (BOOL)useSimpleBackground {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kUseSimpleBackgroundKey];
}

- (void)setUseSimpleBackground:(BOOL)bApplied {
    [[NSUserDefaults standardUserDefaults] setBool:bApplied forKey:kUseSimpleBackgroundKey];
}

@end
