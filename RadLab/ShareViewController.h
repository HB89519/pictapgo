//
//  ShareViewController.h
//  RadLab
//
//  Created by Geoff Scott on 10/31/12.
//  Copyright (c) 2012 Totally Rad. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ImageDataController.h"
#import "PTGButton.h"
#import "SaveRecipeViewController.h"
#import "WorkspaceViewController.h"

@interface ShareViewController : UIViewController <SaveRecipeViewControllerDelegate,
                                                    UIDocumentInteractionControllerDelegate>

@property (weak, nonatomic) ImageDataController *dataController;
@property (weak, nonatomic) id<WorkspaceViewPopoverDelegate> popoverDelegate;
@property (strong, nonatomic) UIDocumentInteractionController* documentInteractionController;
@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UIImageView *blurredBackground;
@property (weak, nonatomic) IBOutlet PTGButton *saveRecipeButton;
@property (weak, nonatomic) IBOutlet PTGButton *renderedButton;
@property (weak, nonatomic) IBOutlet PTGButton *instagramCropButton;
@property (weak, nonatomic) IBOutlet PTGButton *instagramWhiteButton;
@property (weak, nonatomic) IBOutlet PTGButton *instagramFloatButton;
@property (weak, nonatomic) IBOutlet PTGButton *facebookButton;
@property (weak, nonatomic) IBOutlet PTGButton *twitterButton;
@property (weak, nonatomic) IBOutlet PTGButton *openInButton;
@property (weak, nonatomic) IBOutlet PTGButton *clipboardButton;
@property (weak, nonatomic) IBOutlet UIButton *tapButton;

- (IBAction)doBack:(id)sender;
- (IBAction)doChoose:(id)sender;
- (IBAction)doSaveReceipe:(id)sender;
- (IBAction)doSaveRendered:(id)sender;
- (IBAction)doCopyToClipboard:(id)sender;
- (IBAction)doOpenIn:(id)sender;
- (IBAction)doShareInstagramBorder:(id)sender;
- (IBAction)doShareInstagramCrop:(id)sender;
- (IBAction)doShareInstagramFloat:(id)sender;
- (IBAction)doShareFacebook:(id)sender;
- (IBAction)doShareTwitter:(id)sender;

- (IBAction)doShareMail:(id)sender;
- (IBAction)doShareIM:(id)sender;
- (IBAction)doShareFlickr:(id)sender;
- (IBAction)doShareAirDrop:(id)sender;

- (IBAction)doShareGooglePlus:(id)sender;
- (IBAction)doSharePinterest:(id)sender;

@end
