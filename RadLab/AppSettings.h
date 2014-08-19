//
//  AppSettings.h
//  RadLab
//
//  Created by Tim Ruddick on 2/7/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum { kPermissionsOK, kPermissionsQuitBuggingMe } PermissionsCheck;

@interface AppSettings : NSObject
+ (AppSettings*) manager;
+ (void)setup;
+ (void)synchronize;
+ (void)resetToDefaults;
+ (void)resetHelpToDefaults;
@property NSInteger editViewInitialFolder;
@property BOOL visitedPicScreen;
@property BOOL visitedTapScreen;
@property BOOL visited2ndTapScreen;
@property BOOL visitedGoScreen;
@property BOOL appliedTwoFilters;
@property BOOL useSimpleBackground;
@property PermissionsCheck permissionsCheck;
@end
