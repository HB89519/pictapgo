//
//  CameraOverlayViewController.h
//  RadLab
//
//  Created by Geoff Scott on 10/29/12.
//  Copyright (c) 2012 Totally Rad. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>
#import <AVFoundation/AVFoundation.h>

@protocol CameraOverlayViewControllerDelegate;

@interface CameraOverlayViewController : UIViewController <UINavigationControllerDelegate,
                                                            UIImagePickerControllerDelegate>
@property (strong, nonatomic) AVCaptureDevice* device;
@property (weak, nonatomic) id<CameraOverlayViewControllerDelegate> delegate;
@property (nonatomic, retain) UIImagePickerController *imagePickerController;

- (void)setupCamera:(BOOL)useCustomControls allowsEditing:(BOOL)editingOption locationManager:(CLLocationManager*)manager;
- (IBAction)takePhoto:(id)sender;
- (IBAction)doCancel:(id)sender;
-(void)volumeChanged:(NSNotification *)notification;

@end

@protocol CameraOverlayViewControllerDelegate

- (void)didTakePicture:(UIImage*)picture metadata:(NSDictionary*)metadata;
- (void)didCancelCamera;

@end
