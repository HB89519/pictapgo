//
//  SaveRecipeViewController.h
//  RadLab
//
//  Created by Geoff Scott on 2/1/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ImageDataController.h"

@protocol SaveRecipeViewControllerDelegate;

@interface SaveRecipeViewController : UIViewController <UITextFieldDelegate>

@property (weak, nonatomic) ImageDataController *dataController;
@property (weak, nonatomic) id<SaveRecipeViewControllerDelegate> delegate;
@property (weak, nonatomic) IBOutlet UIView *step1View;
@property (weak, nonatomic) IBOutlet UIView *step2View;
@property (weak, nonatomic) IBOutlet UIView *step3View;
@property (weak, nonatomic) IBOutlet UIView *step4View;
@property (weak, nonatomic) IBOutlet UIView *step5View;
@property (weak, nonatomic) IBOutlet UIView *step6View;
@property (weak, nonatomic) IBOutlet UITextField *recipeNameField;
@property (weak, nonatomic) IBOutlet UIButton *OKButton;
@property (weak, nonatomic) IBOutlet UIButton *cancelButton;

- (IBAction)doCancel:(id)sender;
- (IBAction)doSave:(id)sender;

@end

@protocol SaveRecipeViewControllerDelegate <NSObject>

- (void)saveRecipeViewControllerDoCancel:(SaveRecipeViewController *)controller;
- (void)saveRecipeViewControllerDoSave:(SaveRecipeViewController *)controller withRecipeName:(NSString *)recipeName;

@end