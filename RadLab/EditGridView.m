//
//  EditGridView.m
//  RadLab
//
//  Created by Geoff Scott on 11/15/12.
//  Copyright (c) 2012 Totally Rad. All rights reserved.
//

#import "EditGridView.h"

@implementation EditGridView

@synthesize cellList = _cellList;
@synthesize cellNib = _cellNib;
@synthesize contentFrame = _contentFrame;

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        NSMutableArray *myList = [[NSMutableArray alloc] init];
        [self setCellList:myList];
        self.cellNib = [UINib nibWithNibName:@"ThumbnailViewCell" bundle:nil];
//        [self buildGrid];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    if (self) {
        NSMutableArray *myList = [[NSMutableArray alloc] init];
        [self setCellList:myList];
        self.cellNib = [UINib nibWithNibName:@"ThumbnailViewCell" bundle:nil];
//        [self buildGrid];
    }
    return self;
}

- (void)setCellList:(NSMutableArray *)newList {
    if (_cellList != newList) {
        _cellList = [newList mutableCopy];
    }
}

- (void)buildGrid {
    CGPoint curOrigin = CGPointMake(0.0, 0.0);
    CGRect newGridFrame;
    
    for (NSInteger i = 0; i < [self.dataSource editGridView:self numberOfItemsInSection:0]; i++) {
        EditGridViewCell *curCell = [self buildEmptyCell];
        [self.cellList addObject:curCell];
        
        // place the cell in the view at the next spot
        newGridFrame = CGRectMake(curOrigin.x, curOrigin.y, curCell.frame.size.width, curCell.frame.size.height);
        [curCell setFrame:newGridFrame];
        [self addSubview:curCell];
        
        // adjust the origin for the next cell
        if (curOrigin.x == self.frame.origin.x) {
            // move the origin to the left
            curOrigin.x += newGridFrame.size.width;
        } else {
            // move the origin to the next line and back to the right
            curOrigin.x = self.frame.origin.x;
            curOrigin.y += newGridFrame.size.height;
        }
    }
    
    // adjust the frame of the gridView
    CGRect newFrame = CGRectMake(self.frame.origin.x, self.frame.origin.y, newGridFrame.size.width * 2, newGridFrame.origin.y + newGridFrame.size.height);
    [self setFrame:newFrame];
    [self setContentFrame:newFrame];
    [self setNeedsDisplay];
}

- (EditGridViewCell *)buildEmptyCell {
    [self.cellNib instantiateWithOwner:self options:nil];
    EditGridViewCell *retCell = self.tmpCell;
    self.tmpCell = nil;
    
    return retCell;
}

- (EditGridViewCell *)cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    return [self.cellList objectAtIndex: indexPath.row];
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
}

- (void)setBounds:(CGRect)bounds {
    bounds.size = self.contentFrame.size;
    [super setBounds:bounds];
//    [super setBounds:self.contentFrame];
}

#if geofftest
- (CGSize)sizeThatFits:(CGSize)size {
    return self.contentFrame.size;
}

+ (BOOL)requiresConstraintBasedLayout {
    return YES;
}
#endif

- (void)layoutSubviews {
    [super layoutSubviews];
}

- (void)reloadData {
    // geofftest - need to have the cells all reload the data
    CGRect redrawRect = self.bounds;
    redrawRect = self.frame;
    redrawRect = self.contentFrame;
    [self setFrame:self.contentFrame];
//    [self setBounds:self.contentFrame];
    redrawRect = self.frame;
    redrawRect = self.bounds;
// geofftest    [self setNeedsDisplayInRect:redrawRect];
    [self setNeedsDisplay];
/*
    // brute force this - geofftest
    for (NSUInteger i = 0; i < [self.cellList count]; i++) {
        EditGridViewCell *cell = [self.cellList objectAtIndex:i];
        NSIndexPath *curPath = [NSIndexPath indexPathForRow:i inSection:0];
        [self.dataSource reloadDataForCell:cell withIndexPath:curPath];
    }
*/
}

- (void)drawRect:(CGRect)destRect
{
    for (NSUInteger i = 0; i < [self.cellList count]; i++) {
        EditGridViewCell *cell = [self.cellList objectAtIndex:i];
        if (CGRectIntersectsRect(destRect, cell.frame)) {
            NSIndexPath *curPath = [NSIndexPath indexPathForRow:i inSection:0];
            [self.dataSource reloadDataForCell:cell withIndexPath:curPath];
            [cell drawRect:destRect];
        }
    }
}

- (IBAction)handleTap:(UITapGestureRecognizer *)recognizer {
    if ([recognizer state] == UIGestureRecognizerStateEnded) {
        CGPoint tapPt = [recognizer locationInView:self];
//        if (CGRectContainsPoint(self.frame, tapPt)) {
            for (NSUInteger i = 0; i < [self.cellList count]; i++) {
                EditGridViewCell *cell = [self.cellList objectAtIndex:i];
                if (CGRectContainsPoint(cell.frame, tapPt)) {
                    NSIndexPath *curPath = [NSIndexPath indexPathForRow:i inSection:0];
                    [self.delegate editGridView:self didSelectItemAtIndexPath:curPath];
                    break;
                }
            }
//        }
    }
}

@end
