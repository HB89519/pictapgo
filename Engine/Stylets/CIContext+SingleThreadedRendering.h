//
//  CIContext+SingleThreadedRendering.h
//  RadLab
//
//  Created by Tim Ruddick on 3/14/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import <CoreImage/CoreImage.h>

@interface CIContext (SingleThreadedRendering)
+ (void) blockCoreImageUsage;
+ (void) unblockCoreImageUsage;
- (CGImageRef) createCGImageMoreSafely:(CIImage*)inputImage fromRect:(CGRect)size CF_RETURNS_RETAINED;
@end
