//
//  SaveRecipeViewController.m
//  RadLab
//
//  Created by Geoff Scott on 2/1/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import "SaveRecipeViewController.h"
#import "DDLog.h"
#import "EditGridViewCell.h"
#import "MemoryStatistics.h"
#import "UICommon.h"

static int ddLogLevel = LOG_LEVEL_INFO;

@interface SaveRecipeViewController ()
{
    float _saveY;
}
@end

static const CGFloat kExtraPadding = 6.0;

@implementation SaveRecipeViewController

@synthesize dataController = _dataController;
@synthesize delegate = _delegate;
@synthesize step1View = _step1View;
@synthesize step2View = _step2View;
@synthesize step3View = _step3View;
@synthesize step4View = _step4View;
@synthesize step5View = _step5View;
@synthesize step6View = _step6View;
@synthesize recipeNameField = _recipeNameField;
@synthesize OKButton = _OKButton;
@synthesize cancelButton = _cancelButton;

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)registerForKeyboardNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWasShown:)
                                                 name:UIKeyboardDidShowNotification object:nil];
}

- (void)keyboardWasShown:(NSNotification*)aNotification {
    if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
        NSDictionary* info = [aNotification userInfo];
        CGSize kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
        NSNumber *kbHeight = [NSNumber numberWithInt:kbSize.height];
        [self performSelectorOnMainThread:@selector(adjustForKeyboardHeight:) withObject:kbHeight waitUntilDone:NO];
        kbHeight = nil;
    }
}

- (void)adjustForKeyboardHeight:(NSNumber*)kbHeight {
    CGRect newFrame = self.view.frame;
    
    // calculate how much the whole frame needs to move to see keyboard and edit field + Save & Cancel buttons
    float newY = newFrame.size.height - self.recipeNameField.frame.origin.y - self.recipeNameField.frame.size.height - kbHeight.intValue - self.cancelButton.frame.size.height + kExtraPadding;
    if (newY < newFrame.origin.y) {
        _saveY = newFrame.origin.y;
        newFrame.origin.y = newY;
    }
    
    [UIView animateWithDuration:0.25f
                          delay:0.0f
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         [self.view setFrame:newFrame];
                     }
                     completion:nil
     ];
}

- (void)textChanged:(id)sender {
    [self.OKButton setEnabled:(self.recipeNameField.text.length > 0)];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _saveY = self.view.frame.origin.y;
    [self.OKButton setEnabled:NO];
    [self registerForKeyboardNotifications];
    [self.recipeNameField addTarget:self action:@selector(textChanged:) forControlEvents:UIControlEventAllEditingEvents];
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self loadRecipeSteps];
    [self adjustUpIfNeeded];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    if (self.isViewLoaded && self.view.window == nil) {
        DDLogInfo(@"begin SaveRecipe didReceiveMemoryWarning (mem %@)", stringWithMemoryInfo());
        self.view = nil;
        DDLogInfo(@"finished SaveRecipe didReceiveMemoryWarning (mem %@)", stringWithMemoryInfo());
    }
}

- (void)showRecipeStep:(NSUInteger)stepNumber inParent:(UIView *)view {
    NSArray *nibContents = [[NSBundle mainBundle] loadNibNamed:@"RecipeStepView" owner:self options:nil];
    EditGridViewCell *stepcell = [nibContents objectAtIndex:0];
    [view addSubview:stepcell];
    [stepcell setImage:[self.dataController thumbnailForRecipeStep:stepNumber]];
    
    ThumbnailAttributes* attrs = [self.dataController styletAttributesForRecipeStep:stepNumber];
    if ([attrs strength] == 100) {
        [stepcell setStyletName:[attrs name]];
    } else {
        [stepcell setStyletName:[NSString stringWithFormat:@"%zd%% %@", [attrs strength], [attrs name]]];
    }
    [stepcell setCellType:[attrs type]];

    CGRect newFrame = [view frame];
    newFrame.origin.x = 0.0;
    newFrame.origin.y = 0.0;
    [stepcell setFrame:newFrame];
}

- (void)showAggregateStep {
    NSArray *nibContents = [[NSBundle mainBundle] loadNibNamed:@"RecipeStepView" owner:self options:nil];
    EditGridViewCell *stepcell = [nibContents objectAtIndex:0];
    [self.step6View addSubview:stepcell];
    [stepcell setImage:[self.dataController currentThumbAtCurrentStrength]];
    [stepcell setStyletName:[NSString stringWithFormat:NSLocalizedString(@"+%d more steps", nil), [self.dataController appliedStepsCount] - 6]];
    [stepcell setCellType:kRecipeCellType];
    
    CGRect newFrame = [self.step6View frame];
    newFrame.origin.x = 0.0;
    newFrame.origin.y = 0.0;
    [stepcell setFrame:newFrame];
}

- (void)clearRecipeStep:(UIView *)view {
    while (view.subviews.count > 0) {
        UIView *subview = [view.subviews lastObject];
        [subview removeFromSuperview];
    }
}

- (void)loadRecipeSteps {
    NSArray* stepViews = [NSArray arrayWithObjects:
      [NSNull null], // placeholder for recipe step 0
      self.step1View, self.step2View, self.step3View,
      self.step4View, self.step5View, self.step6View,
      nil];
    const NSUInteger stepCount = self.dataController.appliedStepsCount;
    for (int s = 1; s <= 6; ++s) {
        if (s == 6 && stepCount > 7) {
            [self showAggregateStep];
        } else if (s >= stepCount) {
            [self clearRecipeStep:[stepViews objectAtIndex:s]];
        } else {
            [self showRecipeStep:s inParent:[stepViews objectAtIndex:s]];
        }
    }
}

- (void)adjustUpIfNeeded {
    // if less than 4 steps, move things up to look nicer
    if ([self.dataController appliedStepsCount] <= 4) {
        // must adjust the text input field up
        CGRect newFrame = self.recipeNameField.frame;
        newFrame.origin.y = self.step4View.frame.origin.y;
        [self.recipeNameField setFrame:newFrame];
        
        // the cancel button up
        CGRect newButtonFrame = self.cancelButton.frame;
        newButtonFrame.origin.y = newFrame.origin.y + newFrame.size.height + kExtraPadding;
        [self.cancelButton setFrame:newButtonFrame];
        
        // the OK button
        newButtonFrame = self.OKButton.frame;
        newButtonFrame.origin.y = newFrame.origin.y + newFrame.size.height + kExtraPadding;
        [self.OKButton setFrame:newButtonFrame];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self adjustUpIfNeeded];
}

- (IBAction)doCancel:(id)sender {
    [self.delegate saveRecipeViewControllerDoCancel:self];
}

- (IBAction)doSave:(id)sender {
    [self.delegate saveRecipeViewControllerDoSave:self withRecipeName:self.recipeNameField.text];
}

#pragma mark - UITextFieldDelegate
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == self.recipeNameField) {
        [textField resignFirstResponder];
    }
    
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    CGRect newFrame = self.view.frame;
    if (newFrame.origin.y != _saveY) {
        newFrame.origin.y = _saveY;
        
        [UIView animateWithDuration:0.25f
                              delay:0.0f
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
                             [self.view setFrame:newFrame];
                         }
                         completion:nil
         ];
    }

    [self.OKButton setEnabled:(textField.text.length > 0)];
}

@end
