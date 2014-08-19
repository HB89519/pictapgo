//
//  TRUploadState.h
//  RadLab
//
//  Created by Tim Ruddick on 8/5/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface TRUploadState : NSManagedObject

@property (nonatomic, retain) NSDate * timestamp;
@property (nonatomic, retain) NSString * user_uuid;
@property (nonatomic, retain) NSString * user_uuid_old;
@property (nonatomic, retain) NSString * user_email_address;

@end
