//
//  PTGPageControl.m
//  RadLab
//
//  Created by Geoff Scott on 2/8/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import "PTGPageControl.h"
#import <QuartzCore/QuartzCore.h>

@interface PTGPageControl ()
{
    NSMutableArray* _imageViewList;
}

@end

static const CGFloat kPageSpacing = 4.0;

@implementation PTGPageControl

@synthesize numberOfPages = _numberOfPages;
@synthesize currentPage = _currentPage;

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupData];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self setupData];
    }
    return self;
}

- (void)setupData {
    _imageViewList = [[NSMutableArray alloc] init];
    [self resetPageCount];
}

- (UIImageView *)createNewPageWith:(UIImage *)image {
    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
    
    [imageView setContentMode:UIViewContentModeScaleAspectFill];
    [imageView setClipsToBounds:YES];
    imageView.layer.shadowOpacity = 0.85;
    imageView.layer.shadowRadius = 1.5;
    imageView.layer.shadowOffset = CGSizeMake(0, 1.5);
    
    return imageView;
}

- (void)resetPageCount {
    _numberOfPages = 0;
    _currentPage = 0;
    
    // clear everything already displayed
    for (NSUInteger i = 0; i < [_imageViewList count]; i++) {
        UIImageView *imageView = [_imageViewList objectAtIndex:i];
        [imageView removeFromSuperview];
    }
    [_imageViewList removeAllObjects];

    // add an empty page
    UIImageView *imageView = [self createNewPageWith:[UIImage imageNamed:@"Icon_EmptyFilter.png"]];
    [self addSubview:imageView];
    [_imageViewList addObject:imageView];
    [self updatePageDisplay];
}

- (void)setNumberOfPages:(NSUInteger)numberOfPages {
    _numberOfPages = numberOfPages;
}

- (void)setCurrentPage:(NSUInteger)currentPage {
    if (_currentPage != currentPage
        && currentPage <= _numberOfPages
        && currentPage > 0) {
        _currentPage = currentPage;
    
        for (NSUInteger i = 0; i < [_imageViewList count]; i++) {
            UIImageView *imageView = [_imageViewList objectAtIndex:i];
            [self setPageBorder:imageView markIt:(i + 1 == self.currentPage)];
        }
    }
}

- (void)setImage:(UIImage *)image forPage:(NSUInteger)pageNumber {
    if (pageNumber >= [_imageViewList count]) {        
        // place the new image in the view for the empty image
        UIImageView *lastImageView = [_imageViewList objectAtIndex:[_imageViewList count] - 1];
        UIImage *emptyImage = lastImageView.image;
        [lastImageView setImage:image];
        
        // add new image view with the empty filter
        UIImageView *imageView = [self createNewPageWith:emptyImage];
        [self addSubview:imageView];
        [_imageViewList addObject:imageView];
        [self updatePageDisplay];
    } else {
        UIImageView *curImageView = [_imageViewList objectAtIndex:pageNumber - 1];
        if (curImageView.image != image) {
            [curImageView setImage:image];
        }
    }
}

- (void)setPageBorder:(UIImageView *)imageView markIt:(BOOL)isCurrent {
    if (isCurrent) {
        imageView.layer.borderColor = [[UIColor yellowColor] CGColor];
        imageView.layer.borderWidth = 2.0;
    } else {
        imageView.layer.borderWidth = 0.0;
    }
}

- (void)updatePageDisplay {
    CGFloat widthForImages = [_imageViewList count] * self.frame.size.height + [_imageViewList count] * kPageSpacing;
    CGFloat currentX = (self.frame.size.width - widthForImages) / 2;
    
    for (NSUInteger i = 0; i < [_imageViewList count]; i++) {
        CGRect newFrame;
        newFrame.origin.x = currentX;
        newFrame.origin.y = 0;
        newFrame.size.width = self.frame.size.height;
        newFrame.size.height = self.frame.size.height;
        
        UIImageView *imageView = [_imageViewList objectAtIndex:i];
        [imageView setFrame:newFrame];
        [self setPageBorder:imageView markIt:(i + 1 == self.currentPage)];
        
        currentX += self.frame.size.height + kPageSpacing;
    }
}

@end
