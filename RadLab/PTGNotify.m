//
//  PTGNotify.m
//  RadLab
//
//  Created by Geoff Scott on 1/30/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import "PTGNotify.h"
#import <QuartzCore/QuartzCore.h>
#import "UICommon.h"

static int ddLogLevel = LOG_LEVEL_INFO;

static PTGNotify *_messageOverlay = nil;
static displayDoneBlock _dismissDoneBlock = nil;

@implementation PTGNotify

@synthesize titleLabel = _titleLabel;
@synthesize pageNumLabel = _pageNumLabel;
@synthesize messageField = _messageField;
@synthesize dismissButton = _dismissButton;
@synthesize contentView = _contentView;
@synthesize backgroundView = _backgroundView;

- (IBAction)doDismiss:(id)sender {
    [PTGNotify reset];
}

+ (void)reset {
    if (_messageOverlay) {
        [_messageOverlay removeFromSuperview];
        _messageOverlay = nil;
    }
    if (_dismissDoneBlock) {
        _dismissDoneBlock();
        _dismissDoneBlock = nil;
    }
}

+ (UIView*)findDisplayViewFromViewController:(UIViewController *)parentViewController {
    UIView* parentView = parentViewController.view;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        UIViewController *viewController = (UIViewController *)[UIApplication sharedApplication].delegate.window.rootViewController;
        if (viewController != NULL ) {
            parentView = viewController.view;
        }
    }
    return parentView;
}

+ (BOOL)isMessageCurrentlyDisplayed {
    return (_messageOverlay != nil);
}

+ (void)displayMessage:(NSString *)message aboveViewController:(UIViewController *)parentViewController {
    [PTGNotify displayMessage:message aboveViewController:parentViewController forDuration:1.0f withCompletionBlock:nil];
}

+ (void)displayMessage:(NSString *)message aboveViewController:(UIViewController *)parentViewController withCompletionBlock:(displayDoneBlock)doneBlock {
    [PTGNotify displayMessage:message aboveViewController:parentViewController forDuration:1.0f withCompletionBlock:doneBlock];
}

+ (void)displayMessage:(NSString *)message aboveViewController:(UIViewController *)parentViewController
           forDuration:(NSTimeInterval)onScreenDuration {
    [PTGNotify displayMessage:message aboveViewController:parentViewController forDuration:onScreenDuration withCompletionBlock:nil];
}

+ (void)displayMessage:(NSString *)message aboveViewController:(UIViewController *)parentViewController forDuration:(NSTimeInterval)onScreenDuration withCompletionBlock:(displayDoneBlock)doneBlock
{
    [PTGNotify reset];
    NSArray *nibContents = [[NSBundle mainBundle] loadNibNamed:@"Notify_Message" owner:self options:nil];
    if (nibContents) {
        UIView* parentView = [PTGNotify findDisplayViewFromViewController:parentViewController];

        _messageOverlay = [nibContents objectAtIndex:0];
        _messageOverlay.contentView.layer.cornerRadius = 8.0;
        _messageOverlay.contentView.layer.masksToBounds = YES;
        [_messageOverlay setAlpha:0.0];
        [_messageOverlay.messageField setText:message];
        _dismissDoneBlock = doneBlock;
        
        CGRect screenRect = currentScreenRect();
        [_messageOverlay setFrame:screenRect];
        [parentView addSubview:_messageOverlay];
    
        // set up the animation to fade in
        [UIView animateWithDuration:0.25f
                              delay:0.0f
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
                             [_messageOverlay setAlpha:0.9];
                         }
                         completion:^(BOOL finished){
                             if (finished) {
                                 // set up animation to fade out
                                 [UIView animateWithDuration:0.25f
                                                       delay:onScreenDuration
                                                     options:UIViewAnimationOptionCurveEaseInOut
                                                  animations:^{
                                                      [_messageOverlay setAlpha:0.0];
                                                  }
                                                  completion:^(BOOL finished){
                                                      if (finished) {
                                                          [PTGNotify reset];
                                                      }
                                                  }
                                  ];
                             }
                         }

         ];
    }
}

+ (void)displayInitialHelp:(NSString *)helpFileName
            withAlertTitle:(NSString *)titleText
                pageNumber:(NSUInteger)pageNum
          ofTotalPageCount:(NSUInteger)totalPages
           withButtonTitle:(NSString *)buttonText
                 aboveViewController:(UIViewController *)parentViewController {
    [PTGNotify displayInitialHelp:helpFileName
                   withAlertTitle:titleText
                       pageNumber:pageNum
                 ofTotalPageCount:totalPages
                  withButtonTitle:buttonText
              aboveViewController:parentViewController withCompletionBlock:nil];
}

+ (void)displayInitialHelp:(NSString *)helpFileName
            withAlertTitle:(NSString *)titleText
                pageNumber:(NSUInteger)pageNum
          ofTotalPageCount:(NSUInteger)totalPages
           withButtonTitle:(NSString *)buttonText
       aboveViewController:(UIViewController *)parentViewController
       withCompletionBlock:(displayDoneBlock)doneBlock{

    [PTGNotify reset];
    NSArray *nibContents = [[NSBundle mainBundle] loadNibNamed:@"Notify_Help" owner:self options:nil];
    if (nibContents) {
        UIView* parentView = [PTGNotify findDisplayViewFromViewController:parentViewController];

        _messageOverlay = [nibContents objectAtIndex:0];
        [_messageOverlay setAlpha:0.0];
        _messageOverlay.contentView.layer.cornerRadius = 7.5;
        _messageOverlay.contentView.layer.masksToBounds = YES;
        [_messageOverlay.titleLabel setText:titleText];
        _dismissDoneBlock = doneBlock;
        
        NSError *error;
        NSString *helpFilePath = [[NSBundle mainBundle] pathForResource:helpFileName ofType: @"txt"];
        NSString *helpText = [NSString stringWithContentsOfFile:helpFilePath encoding:NSUTF8StringEncoding error: &error];
        if (error)
            DDLogError(@"Error opening %@.txt file: %@", helpFileName, error);
        [_messageOverlay.messageField setText:helpText];
        
        if (totalPages > 0) {
            [_messageOverlay.pageNumLabel setText:[NSString stringWithFormat:@"%zd/%zd", pageNum, totalPages]];
        }
        
        [_messageOverlay.dismissButton setTitle:buttonText forState:UIControlStateNormal];
        
        CGRect screenRect = currentScreenRect();
        [_messageOverlay setFrame:screenRect];
        [parentView addSubview:_messageOverlay];

        // set up the animation to fade in
        [UIView animateWithDuration:0.25f
                              delay:0.0f
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
                             [_messageOverlay setAlpha:1.0];
                         }
                         completion:nil
         
         ];
    }
}

+ (void)showSpinnerAboveViewController:(UIViewController *)parentViewController {
    [PTGNotify reset];
    NSArray *nibContents = [[NSBundle mainBundle] loadNibNamed:@"Notify_Spinner" owner:self options:nil];
    if (nibContents) {
        UIView* parentView = [PTGNotify findDisplayViewFromViewController:parentViewController];
        _messageOverlay = [nibContents objectAtIndex:0];
        CGRect screenRect = currentScreenRect();
        [_messageOverlay setFrame:screenRect];
        [parentView addSubview:_messageOverlay];
    }
}

+ (void)hideSpinner {
    [PTGNotify reset];
}

+ (void)displaySimpleAlert:(NSString *)message {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Alert", nil)
                                                    message:message
                                                   delegate:nil
                                          cancelButtonTitle:NSLocalizedString(@"Continue", nil)
                                          otherButtonTitles:nil];
    
    [alert show];
}

@end
