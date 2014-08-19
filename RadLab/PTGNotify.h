//
//  PTGNotify.h
//  RadLab
//
//  Created by Geoff Scott on 1/30/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PTGNotify : UIView

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *pageNumLabel;
@property (weak, nonatomic) IBOutlet UITextView *messageField;
@property (weak, nonatomic) IBOutlet UIButton *dismissButton;
@property (weak, nonatomic) IBOutlet UIView *contentView;
@property (weak, nonatomic) IBOutlet UIView *backgroundView;

- (IBAction)doDismiss:(id)sender;

+ (BOOL)isMessageCurrentlyDisplayed;
+ (void)reset;

typedef void (^displayDoneBlock)(void);

+ (void)displayMessage:(NSString *)message aboveViewController:(UIViewController *)parentViewController;
+ (void)displayMessage:(NSString *)message aboveViewController:(UIViewController *)parentViewController withCompletionBlock:(displayDoneBlock)doneBlock;
+ (void)displayMessage:(NSString *)message aboveViewController:(UIViewController *)parentViewController forDuration:(NSTimeInterval)onScreenDuration;
+ (void)displayMessage:(NSString *)message aboveViewController:(UIViewController *)parentViewController forDuration:(NSTimeInterval)onScreenDuration withCompletionBlock:(displayDoneBlock)doneBlock;

+ (void)displayInitialHelp:(NSString *)helpFileName
            withAlertTitle:(NSString *)titleText
                pageNumber:(NSUInteger)pageNum
          ofTotalPageCount:(NSUInteger)totalPages
           withButtonTitle:(NSString *)buttonText
       aboveViewController:(UIViewController *)parentViewController;
+ (void)displayInitialHelp:(NSString *)helpFileName
            withAlertTitle:(NSString *)titleText
                pageNumber:(NSUInteger)pageNum
          ofTotalPageCount:(NSUInteger)totalPages
           withButtonTitle:(NSString *)buttonText
       aboveViewController:(UIViewController *)parentViewController
       withCompletionBlock:(displayDoneBlock)doneBlock;

+ (void)showSpinnerAboveViewController:(UIViewController *)parentViewController;
+ (void)hideSpinner;

+ (void)displaySimpleAlert:(NSString *)message;

@end
