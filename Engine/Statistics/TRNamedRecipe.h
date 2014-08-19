//
//  TRNamedRecipe.h
//  RadLab
//
//  Created by Tim Ruddick on 7/17/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface TRNamedRecipe : NSManagedObject

@property (nonatomic, retain) NSNumber * builtin;
@property (nonatomic, retain) NSNumber * freshly_imported;
@property (nonatomic, retain) NSString * recipe_code;
@property (nonatomic, retain) NSString * recipe_name;

@end
