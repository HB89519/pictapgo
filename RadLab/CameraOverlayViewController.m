//
//  CameraOverlayViewController.m
//  RadLab
//
//  Created by Geoff Scott on 10/29/12.
//  Copyright (c) 2012 Totally Rad. All rights reserved.
//

#import "CameraOverlayViewController.h"
#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>
#import "DDLog.h"

//static int ddLogLevel = LOG_LEVEL_INFO;

NSDictionary* gpsDictionaryForLocation(CLLocation* location, CLHeading* heading) {
    NSMutableDictionary* gps = [[NSMutableDictionary alloc] init];

    [gps setObject:@"2.2.0.0" forKey:(NSString*)kCGImagePropertyGPSVersion];

    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];

    formatter.dateFormat = @"HH:mm:ss.SSSSSS";
    [gps setObject:[formatter stringFromDate:location.timestamp] forKey:(NSString*)kCGImagePropertyGPSTimeStamp];

    formatter.dateFormat = @"yyyy:MM:dd";
    [gps setObject:[formatter stringFromDate:location.timestamp] forKey:(NSString*)kCGImagePropertyGPSDateStamp];

    CLLocationDegrees lat = location.coordinate.latitude;
    [gps setObject:(lat < 0 ? @"S" : @"N") forKey:(NSString*)kCGImagePropertyGPSLatitudeRef];
    [gps setObject:[NSNumber numberWithDouble:fabs(lat)] forKey:(NSString*)kCGImagePropertyGPSLatitude];

    CLLocationDegrees lng = location.coordinate.longitude;
    [gps setObject:(lng <= 0 ? @"W" : @"E") forKey:(NSString*)kCGImagePropertyGPSLongitudeRef];
    [gps setObject:[NSNumber numberWithDouble:fabs(lng)] forKey:(NSString*)kCGImagePropertyGPSLongitude];

    CLLocationDistance alt = location.altitude;
    if (!isnan(alt)) {
        [gps setObject:(alt < 0 ? @"1" : @"0") forKey:(NSString*)kCGImagePropertyGPSAltitudeRef];
        [gps setObject:[NSNumber numberWithDouble:fabs(alt)] forKey:(NSString*)kCGImagePropertyGPSAltitude];
    }

    if (location.speed >= 0.01) {
        [gps setObject:@"K" forKey:(NSString*)kCGImagePropertyGPSSpeedRef];
        [gps setObject:[NSNumber numberWithDouble:location.speed * 3.6] forKey:(NSString*)kCGImagePropertyGPSSpeed]; // km/h
    }

    if (location.course >= 0) {
        [gps setObject:@"T" forKey:(NSString*)kCGImagePropertyGPSTrackRef];
        [gps setObject:[NSNumber numberWithDouble:location.course] forKey:(NSString*)kCGImagePropertyGPSTrack];
    }

    if (heading) {
        [gps setObject:@"T" forKey:(NSString*)kCGImagePropertyGPSImgDirectionRef];
        [gps setObject:[NSNumber numberWithDouble:heading.trueHeading] forKey:(NSString*)kCGImagePropertyGPSImgDirection];
    }

    return gps;
}

@interface CameraOverlayViewController ()

@property (nonatomic, weak) CLLocationManager* locationManager;

@end;

@implementation CameraOverlayViewController

@synthesize delegate = _delegate;
@synthesize imagePickerController = _imagePickerController;
@synthesize locationManager = _locationManager;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (self) {
        if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
            self.imagePickerController = [[UIImagePickerController alloc] init];
            self.imagePickerController.delegate = self;
            self.imagePickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
            self.imagePickerController.allowsEditing = NO;
//            self.imagePickerController.showsCameraControls = YES;
            
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(volumeChanged:) name:@"AVSystemController_SystemVolumeDidChangeNotification" object:nil];
        
        }
    }
    
    return self;
}
-(void)volumeChanged:(NSNotification *)notification{
    
}

- (void)viewDidUnload {
    [self setImagePickerController:nil];    
    [super viewDidUnload];
}

- (void)setupCamera
{
    NSArray* devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for(AVCaptureDevice *device in devices)
    {
        if([device position] == AVCaptureDevicePositionFront)
            self.device = device;
    }
    
    AVCaptureDeviceInput* input = [AVCaptureDeviceInput deviceInputWithDevice:self.device error:nil];
    AVCaptureVideoDataOutput* output = [[AVCaptureVideoDataOutput alloc] init];
    output.alwaysDiscardsLateVideoFrames = YES;
    
    dispatch_queue_t queue;
    queue = dispatch_queue_create("cameraQueue", NULL);
    [output setSampleBufferDelegate:self queue:queue];
    
    NSString* key = (NSString *) kCVPixelBufferPixelFormatTypeKey;
    NSNumber* value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA];
    NSDictionary* videoSettings = [NSDictionary dictionaryWithObject:value forKey:key];
    [output setVideoSettings:videoSettings];
    
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef newContext = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGImageRef newImage = CGBitmapContextCreateImage(newContext);
    
    CGContextRelease(newContext);
    CGColorSpaceRelease(colorSpace);
    
    self.cameraImage = [UIImage imageWithCGImage:newImage scale:1.0f orientation:UIImageOrientationLeftMirrored];
    
    CGImageRelease(newImage);
    
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
}
- (AVCaptureDevice *) cameraWithPosition:(AVCaptureDevicePosition) position
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices)
    {
        if ([device position] == position) return device;
    }
    return nil;
}
- (IBAction)galleryAction:(id)sender {
    UIImagePickerController *imagePickerController = [[UIImagePickerController alloc]init];
    imagePickerController = [[UIImagePickerController alloc] init];
    imagePickerController.delegate = self;
    imagePickerController.sourceType =  UIImagePickerControllerSourceTypePhotoLibrary;
    
    [self.navigationController presentViewController:imagePickerController animated:YES completion:nil];
}
- (IBAction)takePhoto:(id)sender {
    [self.imagePickerController takePicture];
}

- (IBAction)doCancel:(id)sender {
    [self.delegate didCancelCamera];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *image = [info valueForKey:UIImagePickerControllerOriginalImage];
    if (self.imagePickerController.allowsEditing)
        image = [info valueForKey:UIImagePickerControllerEditedImage];

    CLLocation* location = nil;
    CLHeading* heading = nil;
    if (self.locationManager) {
        [self.locationManager stopUpdatingLocation];
        location = self.locationManager.location;
        if ([CLLocationManager headingAvailable]) {
            heading = self.locationManager.heading;
            [self.locationManager stopUpdatingHeading];
        }
    }

    NSMutableDictionary* metadata = [[info valueForKey:UIImagePickerControllerMediaMetadata] mutableCopy];
    if (location)
        [metadata setValue:gpsDictionaryForLocation(location, heading) forKey:(NSString*)kCGImagePropertyGPSDictionary];
    [self.delegate didTakePicture:image metadata:metadata];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    // tell our delegate we are finished with the picker
    [self.delegate didCancelCamera];
}

@end
