//
//  TRMagicWeight.h
//  RadLab
//
//  Created by Tim Ruddick on 7/17/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface TRMagicWeight : NSManagedObject

@property (nonatomic, retain) NSString * recipe_code;
@property (nonatomic, retain) NSNumber * weight;

@end
