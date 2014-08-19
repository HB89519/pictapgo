//
//  PreviewViewController.h
//  RadLab
//
//  Created by Geoff Scott on 11/6/12.
//  Copyright (c) 2012 Totally Rad. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ImageDataController.h"

@protocol PreviewViewControllerDelegate;

@interface PreviewViewController : UIViewController <ImageDataControllerDelegate,
                                                        UIScrollViewDelegate>

@property (weak, nonatomic) ImageDataController *dataController;
@property (weak, nonatomic) id<PreviewViewControllerDelegate> delegate;
@property (weak, nonatomic) IBOutlet UIImageView *afterImageView;
@property (weak, nonatomic) IBOutlet UIImageView *beforeImageView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *beforeAfterButton;
@property (weak, nonatomic) IBOutlet UISlider *strengthSlider;
@property (weak, nonatomic) IBOutlet UILabel *strengthText;
@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (weak, nonatomic) IBOutlet UIView *containerView;

- (IBAction)doApply:(id)sender;
- (IBAction)doCancel:(id)sender;
- (IBAction)doBeforeAfter:(id)sender;
- (IBAction)doSliderValueChanged:(UISlider *)sender;

- (IBAction)handleDoubleTap:(UIPinchGestureRecognizer *)recognizer;
- (IBAction)handleLongPress:(UILongPressGestureRecognizer *)recognizer;

@end

@protocol PreviewViewControllerDelegate <NSObject>

- (void)previewViewControllerDidCancel:(PreviewViewController *)controller;
- (void)previewViewControllerDidApply:(PreviewViewController *)controller;

@end