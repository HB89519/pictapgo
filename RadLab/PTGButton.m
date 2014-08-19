//
//  PTGButton.m
//  RadLab
//
//  Created by Geoff Scott on 1/10/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import "PTGButton.h"

#import "UICommon.h"

@implementation PTGButton

@synthesize delegate = _delegate;
@synthesize longPressGestureRecognizer = _longPressGestureRecognizer;
@synthesize rotationAngle = _rotationAngle;
@synthesize allowLongPress = _allowLongPress;
@synthesize shareDestinationCode = _shareDestinationCode;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        self.longPressGestureRecognizer = nil;
    }
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    
    // set up long press gesture, if asked
    if (self.allowLongPress) {
        UILongPressGestureRecognizer *theLongPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPressGesture:)];

        // Links the default long press gesture recognizer to the custom long press gesture recognizer we are creating now
        // by enforcing failure dependency so that they doesn't clash.
        for (UIGestureRecognizer *theGestureRecognizer in self.gestureRecognizers) {
            if ([theGestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
                [theGestureRecognizer requireGestureRecognizerToFail:theLongPressGestureRecognizer];
            }
        }
        theLongPressGestureRecognizer.delegate = self;
        [self addGestureRecognizer:theLongPressGestureRecognizer];
        self.longPressGestureRecognizer = theLongPressGestureRecognizer;
    }

    // rotate the button if asked
    if ([self.rotationAngle floatValue] != 0.0) {
        // convert degrees to radians
        self.transform = CGAffineTransformRotate(self.transform, degreesToRadians([self.rotationAngle floatValue]));
    }
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

- (void)handleLongPressGesture:(UILongPressGestureRecognizer *)theLongPressGestureRecognizer {
    if ([theLongPressGestureRecognizer state] == UIGestureRecognizerStateBegan)
        [self.delegate PTGButtonDelegateLongPress:self];
}

#pragma mark - UIGestureRecognizerDelegate methods

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)theGestureRecognizer {
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)theGestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)theOtherGestureRecognizer {
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    return YES;
}

@end
