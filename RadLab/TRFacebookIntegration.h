//
//  TRFacebookIntegration.h
//  RadLab
//
//  Created by Tim Ruddick on 7/16/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import <Foundation/Foundation.h>

static NSString* const FacebookPageIdGetTotallyRad = @"169305903816";
static NSString* const FacebookPageIdPicTapGo = @"558142237548493";

#ifdef USE_FACEBOOKINTEGRATION

@interface TRFacebookIntegration : NSObject
+ (void)notifyAppStarted;
+ (BOOL)isPageLiked_PicTapGo;
+ (BOOL)isPageLiked_GetTotallyRad;
@end

#endif  // USE_FACEBOOKINTEGRATION