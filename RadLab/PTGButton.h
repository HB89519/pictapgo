//
//  PTGButton.h
//  RadLab
//
//  Created by Geoff Scott on 1/10/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol PTGButtonDelegate;

@interface PTGButton : UIButton <UIGestureRecognizerDelegate>

@property (nonatomic, weak) id<PTGButtonDelegate> delegate;
@property (nonatomic, weak) UILongPressGestureRecognizer *longPressGestureRecognizer;
@property (nonatomic, copy) NSString *rotationAngle;
@property (nonatomic, assign) Boolean allowLongPress;
@property (nonatomic, copy) NSString *shareDestinationCode;

@end

@protocol PTGButtonDelegate <NSObject>

- (void)PTGButtonDelegateLongPress:(PTGButton *)sourceButton;

@end