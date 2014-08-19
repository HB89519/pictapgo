//
//  Scaling.m
//  RadLab
//
//  Created by Tim Ruddick on 01/09/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import "Scaling.h"

CGSize scaleArea(CGSize size, size_t area) {
    if (size.width * size.height <= area)
        return size;

    CGFloat scale = 1.0;
    CGFloat aspect = MAX(size.width, size.height) / MIN(size.width, size.height);
    size_t squareArea = area / aspect;
    CGFloat minAxis = floor(sqrt(squareArea));
    scale = minAxis / MIN(size.width, size.height);

    CGSize result = CGSizeMake(size.width * scale, size.height * scale);
    return result;
}

CGSize scaleAspectFit(CGSize size, CGSize bounds) {
    if (size.width <= bounds.width && size.height <= bounds.height)
        return size;
    CGFloat hScale = bounds.width / size.width;
    CGFloat vScale = bounds.height / size.height;
    CGFloat scale = MIN(hScale, vScale);
    return CGSizeMake(size.width * scale, size.height * scale);
}

CGSize scaleAspectFill(CGSize size, CGSize bounds, BOOL bAllowSmaller) {
    if (size.width <= bounds.width && size.height <= bounds.height && bAllowSmaller)
        return size;
    CGFloat hScale = bounds.width / size.width;
    CGFloat vScale = bounds.height / size.height;
    CGFloat scale = MAX(hScale, vScale);
    return CGSizeMake(size.width * scale, size.height * scale);
}

BOOL deviceHasRetinaDisplay() {
    return ([[UIScreen mainScreen] respondsToSelector:@selector(scale)] &&
      [UIScreen mainScreen].scale > 1.0);
}

