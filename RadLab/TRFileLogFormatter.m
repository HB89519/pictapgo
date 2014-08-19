//
//  TRFileLogger.m
//  RadLab
//
//  Created by Tim Ruddick on 7/19/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import "TRFileLogFormatter.h"

@implementation TRFileLogFormatter
- (id)init {
    NSDateFormatter* f = [[NSDateFormatter alloc] init];
    [f setFormatterBehavior:NSDateFormatterBehavior10_4];
    [f setDateFormat:@"MM/dd HH:mm:ss.SSS"];
    return [super initWithDateFormatter:f];
}
- (NSString*)formatLogMessage:(DDLogMessage*)logMessage {
    NSString* dateAndTime = [dateFormatter stringFromDate:(logMessage->timestamp)];
    return [NSString stringWithFormat:@"%@ %4x %@",
      dateAndTime, logMessage->machThreadID, logMessage->logMsg];
}
@end
