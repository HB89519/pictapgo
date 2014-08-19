//
//  CameraCaptureViewController.h
//  DogPlay
//
//  Created by Sergiy on 4/23/14.
//  Copyright (c) 2014 Sergiy. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>
#import <AVFoundation/AVFoundation.h>


@interface CameraCaptureViewController : UIViewController<AVCaptureVideoDataOutputSampleBufferDelegate,UIImagePickerControllerDelegate,UINavigationControllerDelegate>
{
    BOOL fromGallery;
}

@property (strong, nonatomic) IBOutlet UIImageView *cameraImageView;

@property (strong, nonatomic) AVCaptureDevice* device;
@property (strong, nonatomic) AVCaptureSession* captureSession;
@property (strong, nonatomic) AVCaptureVideoPreviewLayer* previewLayer;
@property (strong, nonatomic) UIImage* cameraImage;


- (IBAction)captureAction:(id)sender;
- (IBAction)reverseAction:(id)sender;
- (IBAction)galleryAction:(id)sender;
- (IBAction)backAction:(id)sender;


@end
