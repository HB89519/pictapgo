//
//  TRFileLogger.h
//  RadLab
//
//  Created by Tim Ruddick on 7/19/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import "DDFileLogger.h"

@interface TRFileLogFormatter : DDLogFileFormatterDefault
- (NSString*)formatLogMessage:(DDLogMessage*)logMessage;
@end
