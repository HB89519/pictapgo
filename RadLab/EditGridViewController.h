//
//  EditGridViewController.h
//  RadLab
//
//  Created by Geoff Scott on 10/29/12.
//  Copyright (c) 2012 Totally Rad. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AboutViewController.h"
#import "PTGPageControl.h"
#import "TapEditViewController.h"
#import "MKStoreManager.h"

@interface EditGridViewController : TapEditViewController <UIScrollViewDelegate, MKStoreManagerDelegate,
                                                            AboutViewControllerDelegate>

@property (weak, nonatomic) IBOutlet UIView *folderBar;
@property (weak, nonatomic) IBOutlet UIButton *helpButton;

- (IBAction)doBack:(id)sender;
- (IBAction)doShowHelp:(id)sender;
- (IBAction)doDismissNotification:(id)sender;

- (IBAction)handleSwipeFrom:(UISwipeGestureRecognizer *)recognizer;
- (IBAction)handleTap:(UITapGestureRecognizer *)recognizer;
- (IBAction)handleLongPress:(UILongPressGestureRecognizer *)recognizer;

@end
