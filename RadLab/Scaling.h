//
//  Scaling.h
//  RadLab
//
//  Created by Tim Ruddick on 1/9/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import <Foundation/Foundation.h>

CGSize scaleArea(CGSize size, size_t area);
CGSize scaleAspectFill(CGSize size, CGSize bounds, BOOL bAllowSmaller);
CGSize scaleAspectFit(CGSize size, CGSize bounds);
BOOL deviceHasRetinaDisplay(void);
