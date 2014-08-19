//
//  TapEditViewController.m
//  RadLab
//
//  Created by Geoff Scott on 7/15/13.
//  Copyright (c) 2013 Totally Rad. All rights reserved.
//

#import "TapEditViewController.h"

#import "AppSettings.h"
#import "EditGridHeaderView.h"
#import "EditGridViewCell.h"
#import "LabelHeaderView.h"
#import "MemoryStatistics.h"
#import <MobileCoreServices/UTCoreTypes.h>
#import "PTGNotify.h"
#import <QuartzCore/QuartzCore.h>
#import "ShareViewController.h"
#import "Scaling.h"
#import "ToolViewController.h"
#import "TRStatistics.h"
#import "UICommon.h"
#import "UIDevice-Hardware.h"
#import <libkern/OSAtomic.h>
#import <MessageUI/MessageUI.h>

static int ddLogLevel = LOG_LEVEL_INFO;

// *** additional interface ***

@interface TapEditViewController ()
{
    NSArray* _visibleSections;
    NSNumber *_savedStrength;
    UILabel *_beforeLabel;
    NSIndexPath *_savedIndexPath;
    NSTimer* _refreshTimer;
    volatile uint32_t _thumbnailFlags;
}

@end

// *** constants ***
static NSString *kFilterCellID = @"filterGridID";

static const int kThumbnailFlag_Ready = 0;
static const int kThumbnailFlag_Blocked = 1;
#define MASK_FOR_TESTED_BIT(n) ((0x80 >> (n & 7)) << ((n >> 3) << 3))

// *** implementation ***

@implementation TapEditViewController

// public
@synthesize dataController = _dataController;
@synthesize initialSectionPreference = _initialSectionPreference;
@synthesize blurredBackground = _blurredBackground;
@synthesize gridView = _gridView;
@synthesize afterImageView = _afterImageView;
@synthesize beforeImageView = _beforeImageView;
@synthesize folderTabsImageView = _folderTabsImageView;
@synthesize magicButton = _magicButton;
@synthesize recipeButton = _recipeButton;
@synthesize libraryButton = _libraryButton;
@synthesize storeButton = _storeButton;
@synthesize toolBar = _toolBar;
@synthesize strengthSlider = _strengthSlider;
@synthesize undoButton = _undoButton;
@synthesize redoButton = _redoButton;
@synthesize toolsButton = _toolsButton;

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (_refreshTimer)
        [_refreshTimer invalidate];
    DDLogInfo(@"finish EditGridViewController dealloc (mem %@)", stringWithMemoryInfo());
}

- (void)my_viewWillUnload {
    DDLogInfo(@"will unload Edit view");
#if geofftest
    [self.view.layer removeAllAnimations];
#else
    DDLogInfo(@"will unload Edit view - did nothing");
#endif
}

- (void)my_viewDidUnload {
    DDLogInfo(@"begin did unload Edit view (mem %@)", stringWithMemoryInfo());
#if geofftest
    [self.dataController releaseMemoryForEditView];
#else
    DDLogInfo(@"did NOT call releaseMemoryForEditView");
#endif
    DDLogInfo(@"finish did unload Edit view (mem %@)", stringWithMemoryInfo());
}

- (void)didReceiveMemoryWarning {
    BOOL pendingThumbnails = OSAtomicTestAndClearBarrier(kThumbnailFlag_Ready, &_thumbnailFlags);
    [super didReceiveMemoryWarning];
    if (self.isViewLoaded) {
        if (self.view.window == nil) {
            DDLogInfo(@"begin Edit didReceiveMemoryWarning (mem %@)", stringWithMemoryInfo());
            [self my_viewWillUnload];
#if geofftest
            self.view = nil;
#else
            DDLogInfo(@"didReceiveMemoryWarning - did NOT set self.view to nil");
#endif
            [self my_viewDidUnload];
            DDLogInfo(@"finish Edit didReceiveMemoryWarning (mem %@)", stringWithMemoryInfo());
        } else {
            DDLogInfo(@"purging Edit view caches (mem %@)", stringWithMemoryInfo());
            [self.dataController purgeCaches];
            DDLogInfo(@"finish purging Edit view caches (mem %@)", stringWithMemoryInfo());
        }
    }
    if (pendingThumbnails)
        OSAtomicTestAndSetBarrier(kThumbnailFlag_Ready, &_thumbnailFlags);
}

- (void)testMaskBits {
    for (int i = 0; i < 32; ++i) {
        uint32_t m = MASK_FOR_TESTED_BIT(i);
        volatile uint32_t t = 0;
        OSAtomicTestAndSetBarrier(i, &t);
        NSAssert(m == t, @"m=%#x t=%#x", m, t);
    }
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.toolBar setHidden:![self.dataController hasFiltersApplied]];
    
    _savedStrength = [self.dataController currentStrength];
    [self.strengthSlider setEnabled:NO];
    [self.strengthSlider setMinimumValue:0.0];
    [self.strengthSlider setMaximumValue:100.0];
    [self.strengthSlider setDefaultValue:_savedStrength.floatValue];
    [self.strengthSlider setValue:_savedStrength.floatValue];
    
    [self.undoButton setDelegate:self];
    [self.undoButton setEnabled:NO];
    [self.redoButton setEnabled:NO];
    
    CGRect labelFrame = CGRectMake(0.0, 0.0, 80.0, 22.0);
    _beforeLabel = [[UILabel alloc] initWithFrame:labelFrame];
    [_beforeLabel setTextColor:[UIColor darkGrayColor]];
    [_beforeLabel setBackgroundColor:[UIColor whiteColor]];
    [_beforeLabel setTextAlignment:NSTextAlignmentCenter];
    [_beforeLabel setAlpha:0.7];
    _beforeLabel.layer.cornerRadius = 4.0;
    _beforeLabel.layer.masksToBounds = YES;
    
    _initialSectionPreference = AppSettings.manager.editViewInitialFolder;
    UIButton* initialButton = [self buttonForSection:_initialSectionPreference];
    [self setVisibleSections:initialButton];
    [self setActiveStyletFolder:initialButton];
    [self.magicButton setExclusiveTouch:YES];
    [self.recipeButton setExclusiveTouch:YES];
    [self.libraryButton setExclusiveTouch:YES];
    [self.storeButton setExclusiveTouch:YES];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(thumbnailIndexesRendered:) name:kNotificationThumbnailIndexRendered object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resetVisibleSections:) name:kNotificationResetStyletSections object:nil];

    [self.gridView registerNib:[UINib nibWithNibName:@"LabelHeader" bundle:[NSBundle mainBundle]]
      forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
      withReuseIdentifier:kLabelHeaderID];
    [self.gridView registerNib:[UINib nibWithNibName:@"RecipeHeader" bundle:[NSBundle mainBundle]]
      forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
      withReuseIdentifier:kRecipesHeaderID];
    [self.gridView registerNib:[UINib nibWithNibName:@"StoreBanner" bundle:[NSBundle mainBundle]]
      forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
      withReuseIdentifier:kStoreBannerID];
    // DO NOT do the below. It's a good idea, but in practice the Nib is unloaded
    // a lot and can cause constraint failures at runtime
    //[self.gridView registerNib:[UINib nibWithNibName:@"RecipeStepView" bundle:[NSBundle mainBundle]]
    //  forCellWithReuseIdentifier:kFilterCellID]
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self setAfterImageStrength:self.strengthSlider.value / 100.0];
    setPreviewStylingForView(self.beforeImageView);
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [self setAfterImageStrength:self.strengthSlider.value / 100.0];
    if ([self.dataController currentStepIndex] > 0) {
        [self.strengthSlider setEnabled:YES];
        [self.undoButton setEnabled:YES];
    } else {
        [self.strengthSlider setEnabled:NO];
        [self.undoButton setEnabled:NO];
    }
    
    setupSmileySlider(self.strengthSlider);
    self.redoButton.enabled = !self.currentlyAtLastStep;

    if (_refreshTimer != nil)
        [_refreshTimer invalidate];
    _refreshTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self
      selector:@selector(reloadGrid) userInfo:nil repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [_refreshTimer invalidate];
    _refreshTimer = nil;
}

- (BOOL)currentlyAtLastStep {
    return ([self.dataController currentStepIndex] == [self.dataController appliedStepsCount] - 1);
}

+ (CGSize)thumbnailSize {
    // IMPORTANT: keep this in sync with the storyboard!
    // iPhone numbers are from the storyboard. iPad = x2
    // PTG HD uses the same numbers, even though the image
    // view is a different size and changes.
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        return CGSizeMake(188, 188);
    else
        return CGSizeMake(94, 94);
}

+ (CGSize)previewSize {
    // IMPORTANT: keep this in sync with the storyboard!
    // iPhone numbers are from the storyboard. iPad = x2
    // PTG HD uses the same numbers, even though the image
    // view is a different size and changes.
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        return CGSizeMake(608, 856);
    else
        return CGSizeMake(304, 428);
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"showTools"]) {
        ToolViewController *toolController = (ToolViewController *)[segue destinationViewController];
        [toolController setDelegate:self];
        [toolController setDataController:self.dataController];
    }
}

- (void)setAfterImageStrength:(float)strength {
    [self.afterImageView setAlpha:strength];
}

- (void)setVisibleSections:(UIButton*)button {
    if (button == _magicButton) {
        _visibleSections = [NSArray arrayWithObjects:
                            [NSNumber numberWithInt:kStyletFolderIDMagic],
                            nil];
    } else if (button == _recipeButton) {
        _visibleSections = [NSArray arrayWithObjects:
                            [NSNumber numberWithInt:kStyletFolderIDRecipes],
                            [NSNumber numberWithInt:kStyletFolderIDHistory],
                            nil];
    } else if (button == _libraryButton) {
        _visibleSections = [NSArray arrayWithObjects:
                            [NSNumber numberWithInt:kStyletFolderIDLibrary],
                            nil];
    } else if (button == _storeButton) {
        _visibleSections = [NSArray arrayWithObjects:[NSNumber numberWithInt:kStyletFolderIDStore], nil];
    }
}

- (void)setActiveStyletFolder:(UIButton*)sender {
    [self setVisibleSections:sender];
    
    [self.magicButton setEnabled:[self.dataController hasRecipesOrHistoryOrMagic]];
    [self.recipeButton setEnabled:[self.dataController hasRecipesOrHistoryOrMagic]];
    [self.libraryButton setEnabled:YES];
    [self.storeButton setEnabled:YES];
    
    if (sender == _magicButton) {
        _recipeButton.selected = NO;
        _libraryButton.selected = NO;
        _storeButton.selected = NO;
        [self.folderTabsImageView setImage:[UIImage imageNamed:@"Tab_MyStyles"]];
    } else if (sender == _recipeButton) {
        _magicButton.selected = NO;
        _libraryButton.selected = NO;
        _storeButton.selected = NO;
        [self.folderTabsImageView setImage:[UIImage imageNamed:@"Tab_Recipes"]];
    } else if (sender == _libraryButton) {
        _magicButton.selected = NO;
        _recipeButton.selected = NO;
        _storeButton.selected = NO;
        if ([self.dataController hasRecipesOrHistoryOrMagic]) {
            [self.folderTabsImageView setImage:[UIImage imageNamed:@"Tab_Filters"]];
        } else {
            [self.folderTabsImageView setImage:[UIImage imageNamed:@"Tab_Initial"]];
        }
    } else if (sender == _storeButton) {
        _magicButton.selected = NO;
        _recipeButton.selected = NO;
        _libraryButton.selected = NO;
        if ([self.dataController hasRecipesOrHistoryOrMagic]) {
            [self.folderTabsImageView setImage:[UIImage imageNamed:@"Tab_Store"]];
        } else {
            [self.folderTabsImageView setImage:[UIImage imageNamed:@"Tab_Initial2"]];
        }
    }
    sender.selected = YES;
    
    [_gridView reloadData];
    [_gridView.collectionViewLayout invalidateLayout];
}

- (UIButton*)buttonForSection:(NSInteger)section {
    UIButton *retButton = _libraryButton;
    switch (section) {
        case kStyletFolderIDRecipes:
            retButton = _recipeButton;
            break;
        case kStyletFolderIDHistory:
            retButton = _recipeButton;
            break;
        case kStyletFolderIDMagic:
            retButton = _magicButton;
            break;
        case kStyletFolderIDStore:
            retButton = _storeButton;
    }
    return retButton;
}

- (BOOL)sectionIsVisible:(NSInteger)section {
    return [_visibleSections containsObject:[NSNumber numberWithInteger:section]];
}

- (void)tellDataControllerWhatIsVisible {
    NSArray* visible = [self.gridView indexPathsForVisibleItems];
    NSMutableArray* actuallyVisible = [[NSMutableArray alloc] initWithCapacity:visible.count];
    for (NSIndexPath* p in visible) {
        if (![self cellIsHidden:p])
            [actuallyVisible addObject:p];
    }
    [self.dataController editViewNowShowingSections:[NSArray arrayWithObjects:[NSNumber numberWithInt:kStyletFolderIDLibrary], nil]
                                      andIndexPaths:actuallyVisible];
}

- (void)showRenameRecipe:(NSIndexPath *)indexPath {
    _savedIndexPath = indexPath;
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Rename Recipe", nil)
                                                    message:NSLocalizedString(@"Enter new recipe name", nil)
                                                   delegate:self
                                          cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                          otherButtonTitles:NSLocalizedString(@"Rename", nil), nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    
    UITextField *alertTextField = [alert textFieldAtIndex:0];
    alertTextField.keyboardType = UIKeyboardTypeDefault;
    alertTextField.autocapitalizationType = UITextAutocapitalizationTypeWords;
    alertTextField.placeholder = NSLocalizedString(@"New Recipe Name", nil);
    [alert show];
}

- (void)copyRecipeToClipboard:(NSIndexPath *)indexPath {
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    NSMutableDictionary *pasteDict = [NSMutableDictionary dictionaryWithCapacity:2];
    
    // recipe code as a URL
    ThumbnailAttributes* attrs = [self.dataController styletAttributesAtIndexPath:indexPath];
    NSURL* codeURL = attrs.codeURL;
    [pasteDict setValue:codeURL.absoluteString forKey:(NSString*)kUTTypePlainText];
    
    [pasteboard setItems:[NSArray arrayWithObject:pasteDict]];
    [PTGNotify displayMessage:NSLocalizedString(@"Copied to Clipboard", nil) aboveViewController:self];
    [TRStatistics checkpoint:TRCheckpointCopiedRecipeToClipboard];
}

- (void)emailAllRecipes {
    MFMailComposeViewController* picker = [[MFMailComposeViewController alloc] init];
    picker.mailComposeDelegate = self;
    picker.subject = NSLocalizedString(@"My PicTapGo Recipes", nil);

    NSString* emailBody = NSLocalizedString(
      @"To send all your PicTapGo™ recipes to another device, simply:\n"
       "\n"
       " 1) Send this email to yourself (or another user)\n"
       " 2) Open this email using the device you want to use the recipes on\n"
       " 3) Open the attachment in this email on the target device\n"
       "\n"
       "If PicTapGo is installed on the target device, opening the attached file will import all your recipes into PicTapGo on the target device.", nil);

    NSMutableString* recipeBatch = [[NSMutableString alloc] init];
    NSArray* recipes = [TRStatistics namedRecipeList];
    for (TRNamedRecipe* r in recipes) {
        NSString* name = r.recipe_name;
        if (!name || [name isEqual:@""])
            name = @"«Unnamed Recipe»";
        NSURL* url = [TRStatistics urlWithRecipeCode:r.recipe_code named:name];
        [recipeBatch appendString:url.absoluteString];
        [recipeBatch appendString:@"\n"];
    }
    NSData* attachmentData = [recipeBatch dataUsingEncoding:NSUTF8StringEncoding];

    [picker setMessageBody:emailBody isHTML:NO];
    [picker addAttachmentData:attachmentData mimeType:@"text/x-pictapgo-recipe-batch" fileName:@"My PicTapGo Recipes.pictapgo-recipe-batch"];

    [self presentViewController:picker animated:YES completion:nil];
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
    switch (result) {
    case MFMailComposeResultCancelled:
        DDLogInfo(@"mail cancelled");
        break;
    case MFMailComposeResultSaved:
        DDLogInfo(@"mail saved");
        break;
    case MFMailComposeResultSent:
        DDLogInfo(@"mail sent");
        break;
    case MFMailComposeResultFailed:
        DDLogInfo(@"mail failed");
        break;
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

#define WANT_MAIL_ALL_RECIPES

- (void)showOptionsForRecipeAt:(NSIndexPath *)indexPath {
    _savedIndexPath = indexPath;

    NSString* emailAllRecipes = nil;
  #ifdef WANT_MAIL_ALL_RECIPES
    if ([MFMailComposeViewController canSendMail])
        emailAllRecipes = NSLocalizedString(@"Email all recipes", nil);
  #endif

    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Recipe Options", nil)
                                                             delegate:self
                                                    cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                               destructiveButtonTitle:NSLocalizedString(@"Delete", nil)
                                                    otherButtonTitles:NSLocalizedString(@"Rename", nil),
                                                                      NSLocalizedString(@"Copy Recipe to Clipboard", nil),
                                                                      emailAllRecipes, // NOTE: this may be nil !!!
                                  nil];

    [actionSheet showInView:self.view];
}

- (void)showOptionsForHistoryAt:(NSIndexPath *)indexPath {
    _savedIndexPath = indexPath;
    ThumbnailAttributes* attrs = [self.dataController styletAttributesAtIndexPath:indexPath];
    if (attrs.type == kStyletCellType) {
        return;
    }
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Save Recipe", nil)
                                                    message:NSLocalizedString(@"Name this recipe", nil)
                                                   delegate:self
                                          cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                          otherButtonTitles:NSLocalizedString(@"Continue", nil), nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    
    UITextField *alertTextField = [alert textFieldAtIndex:0];
    alertTextField.keyboardType = UIKeyboardTypeDefault;
    alertTextField.autocapitalizationType = UITextAutocapitalizationTypeWords;
    alertTextField.placeholder = NSLocalizedString(@"New Recipe Name", nil);
    [alert show];
}

- (void)dismissBeforeString {
    [_beforeLabel removeFromSuperview];
}

- (void)animateUndoRedo:(BOOL)direction {
    // intended for derived classes to implement
}

- (void)animateFromGridCell:(EditGridViewCell *)startCell {
    // intended for derived classes to implement
}

- (IBAction)doSliderValueChanged:(PTGSlider *)sender {
    [self setAfterImageStrength:sender.value / 100.0];
}

- (IBAction)doSliderStopped:(PTGSlider *)sender {
    NSNumber* val = [NSNumber numberWithFloat:sender.value];
    if (sender.value < 99.0) {
        [TRStatistics checkpoint:TRCheckpointUsedStrength];
    }
    [self.dataController setCurrentStrength:val];
    [self.gridView reloadData];
    [self setAfterImageStrength:sender.value / 100.0];
}

- (IBAction)doReset:(id)sender {
    if ([self.dataController currentStepIndex] != 0) {
        [TRStatistics checkpoint:TRCheckpointUsedReset];
        [self animateReset];
        
        [self.dataController resetRecipe];
        [self.strengthSlider setMinimumValue:0.0];
        [self.strengthSlider setMaximumValue:100.0];
        [self.strengthSlider setValue:100.0 animated:NO];
        [self.strengthSlider setEnabled:NO];
        [self.undoButton setEnabled:NO];
        [self.redoButton setEnabled:NO];
        [self.gridView reloadData];
    }
}

- (IBAction)doUndo:(id)sender {
    if ([self.dataController undoAppliedStylet]) {
        [self animateUndoRedo:YES];

        [self.gridView reloadData];
        // handled in animation
        // [self.afterImageView setImage:[self.dataController currentPreviewAtFullStrength]];
        [self.beforeImageView setImage:[self.dataController previousPreview]];
        float strength = 1.0;
        if ([self.dataController currentStepIndex] == 0) {
            [self.strengthSlider setEnabled:NO];
            [self.undoButton setEnabled:NO];
        } else {
            strength = [[self.dataController currentStrength] floatValue] / 100.0;
            [self.strengthSlider setEnabled:YES];
            [self.undoButton setEnabled:YES];
        }
        [self.redoButton setEnabled:YES];
        [self.strengthSlider setMinimumValue:0.0];
        [self.strengthSlider setMaximumValue:100.0];
        [self.strengthSlider setValue:[[self.dataController currentStrength] floatValue] animated:NO];
        [self setAfterImageStrength:strength];
    }
}

- (IBAction)doRedo:(id)sender {
    if ([self.dataController redoAppliedStylet]) {
        [self animateUndoRedo:NO];
        
        // handled in animation
        // [self.afterImageView setImage:[self.dataController currentPreviewAtFullStrength]];
        [self.beforeImageView setImage:[self.dataController previousPreview]];
        [self.undoButton setEnabled:YES];
        self.redoButton.enabled = !self.currentlyAtLastStep;
        [self.strengthSlider setMinimumValue:0.0];
        [self.strengthSlider setMaximumValue:100.0];
        [self.strengthSlider setValue:[[self.dataController currentStrength] floatValue] animated:NO];
        [self.strengthSlider setEnabled:YES];
        float strength = [[self.dataController currentStrength] floatValue] / 100.0;
        [self setAfterImageStrength:strength];
    }
}

- (void) animateReset {
    [self animateFromGridCell:nil];
}

- (BOOL)showSecondFilterNotification {
    BOOL retval = NO;
    if (! AppSettings.manager.visited2ndTapScreen) {
        [PTGNotify displayInitialHelp:@"Help_Tap_2" withAlertTitle:NSLocalizedString(@"REFINE IT", nil) pageNumber:3 ofTotalPageCount:4 withButtonTitle:NSLocalizedString(@"Keep Tapping!", nil) aboveViewController:self];
        AppSettings.manager.visited2ndTapScreen = YES;
        retval = YES;
    }
    return retval;
}

- (void)resetVisibleSections_Main {
    _initialSectionPreference = AppSettings.manager.editViewInitialFolder;
    UIButton* initialButton = [self buttonForSection:_initialSectionPreference];
    [self setActiveStyletFolder:initialButton];
}

- (void)resetVisibleSections:(NSNotification*)notification {
    [self performSelectorOnMainThread:@selector(resetVisibleSections_Main) withObject:nil waitUntilDone:NO];
}

- (BOOL)cellIsHidden:(NSIndexPath*)indexPath {
    return ![self sectionIsVisible:indexPath.section];
}

- (void)thumbnailIndexesRendered:(NSNotification*)notification {
    if (!self.isViewLoaded || self.view.window == nil) {
        // do nothing if view is not on-screen
        return;
    }
    OSAtomicTestAndSetBarrier(kThumbnailFlag_Ready, &_thumbnailFlags);
}

- (IBAction)doShowMagicStyletFolder:(id)sender {
    _initialSectionPreference = kStyletFolderIDMagic;
    [self setActiveStyletFolder:sender];
}

- (IBAction)doShowRecipeStyletFolder:(id)sender {
    _initialSectionPreference = kStyletFolderIDRecipes;
    [self setActiveStyletFolder:sender];
}

- (IBAction)doShowLibraryStyletFolder:(id)sender {
    _initialSectionPreference = kStyletFolderIDLibrary;
    [self setActiveStyletFolder:sender];
}

- (IBAction)doShowStoreStyletFolder:(id)sender {
    _initialSectionPreference = kStyletFolderIDStore;
    [self setActiveStyletFolder:sender];
}

- (void)reloadGrid {
    static const uint32_t readyAndBlocked =
      MASK_FOR_TESTED_BIT(kThumbnailFlag_Ready) |
      MASK_FOR_TESTED_BIT(kThumbnailFlag_Blocked);

    if (OSAtomicAnd32Barrier(readyAndBlocked, &_thumbnailFlags) == readyAndBlocked) {
        DDLogInfo(@"reloadGrid blocked while cell highlighted");
        return;
    }

    if (OSAtomicTestAndClearBarrier(kThumbnailFlag_Ready, &_thumbnailFlags)) {
        DDLogInfo(@"refreshing thumbnails (mem %@)", stringWithMemoryInfo());
        [self.gridView reloadData];
    }
}

- (CGRect)calcBeforeStringFrameFrom:(CGRect)labelFrame onSide:(BOOL)bLeftSide {
    return self.view.frame;
}

- (void)displayBeforeString:(NSString *)message onSide:(BOOL)bLeftSide {
    CGRect labelFrame = [self calcBeforeStringFrameFrom:_beforeLabel.frame onSide:bLeftSide];
    [_beforeLabel setFrame:labelFrame];
    [_beforeLabel setText:message];
    [self.view addSubview:_beforeLabel];
}

- (void)showUnlockOptionsForStyletAt:(NSIndexPath *)indexPath {
    _savedIndexPath = indexPath;
    ThumbnailAttributes* attrs = [self.dataController styletAttributesAtIndexPath:indexPath];
    
    NSString *alertMessage = NSLocalizedString(@"Follow us to unlock this filter set.", nil);
    switch (attrs.type) {
        case kLockedMailingListCellType:
            alertMessage = NSLocalizedString(@"Sign up for our mailing list to unlock this free filter.", nil);
            break;
        case kLockedFacebookCellType:
            alertMessage = NSLocalizedString(@"Follow us on Facebook to unlock this free filter.", nil);
            break;
        case kLockedInstagramCellType:
            alertMessage = NSLocalizedString(@"Follow us on Instagram to unlock this free filter.", nil);
            break;
        case kLockedTwitterCellType:
            alertMessage = NSLocalizedString(@"Follow us on Twitter to unlock this free filter.", nil);
            break;
        default:
            break;
    }
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Unlock More Filters", nil)
                                                    message:alertMessage
                                                   delegate:self
                                          cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                          otherButtonTitles:NSLocalizedString(@"Continue", nil), nil];
    alert.alertViewStyle = UIAlertViewStyleDefault;
    [alert show];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView*)view {
    return 5;
}

- (NSInteger)collectionView:(UICollectionView*)view numberOfItemsInSection:(NSInteger)section {
    if (![self sectionIsVisible:section])
        return 1;
    
    if (section == 4) {
        return 0;
    }
    
    if (section == 3) {
        return [self.dataController styletCountInSection:section] + 1;
    }
    else {
        return [self.dataController styletCountInSection:section];
    }
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    EditGridViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:kFilterCellID forIndexPath:indexPath];
    
    if (indexPath.row < [self.dataController styletCountInSection:indexPath.section]) {
        cell.btnAddFilter.hidden = YES;
        cell.imageView.hidden = NO;
        cell.cellBackground.hidden = NO;
        cell.styletLabel.hidden = NO;
        
        ThumbnailAttributes* attrs = [self.dataController styletAttributesAtIndexPath:indexPath];
        [cell setStyletName:attrs.name];
        [cell setCellType:attrs.type];
        
        UIImage* thumb = [self.dataController styletThumbnailAtIndexPath:indexPath];
        [cell setImage:thumb];
        [self tellDataControllerWhatIsVisible];
    }
    else {
        cell.btnAddFilter.hidden = NO;
        cell.imageView.hidden = YES;
        cell.cellBackground.hidden = YES;
        cell.styletLabel.hidden = YES;
        
        [cell.btnAddFilter addTarget:self action:@selector(onAddFilter:) forControlEvents:UIControlEventTouchUpInside];
    }
    
    return cell;
}

- (void)onAddFilter:(UIButton *)sender {
    NSLog(@"onAddFilter");
    [_storeButton sendActionsForControlEvents:UIControlEventTouchUpInside];
}

#pragma mark - UICollectionViewDelegate

- (BOOL)collectionView:(UICollectionView *)collectionView shouldHighlightItemAtIndexPath:(NSIndexPath *)indexPath {
    [self performSelector:@selector(reloadGrid) withObject:nil afterDelay:0.1];
    return YES;
}

- (void)collectionView:(UICollectionView *)collectionView didHighlightItemAtIndexPath:(NSIndexPath *)indexPath {
    DDLogInfo(@"collectionview didHighlightItemAtIndexPath %@", indexPath);
    OSAtomicTestAndSetBarrier(kThumbnailFlag_Blocked, &_thumbnailFlags);
    EditGridViewCell* cell = (EditGridViewCell *)[collectionView cellForItemAtIndexPath:indexPath];
    [cell.imageView setAlpha:0.5];
}

- (void)collectionView:(UICollectionView *)collectionView didUnhighlightItemAtIndexPath:(NSIndexPath *)indexPath {
    DDLogInfo(@"collectionview didUnhighlightItemAtIndexPath %@", indexPath);
    EditGridViewCell* cell = (EditGridViewCell *)[collectionView cellForItemAtIndexPath:indexPath];
    [cell.imageView setAlpha:1.0];
    OSAtomicTestAndClearBarrier(kThumbnailFlag_Blocked, &_thumbnailFlags);
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView*)collectionview
                  layout:(UICollectionViewLayout*)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath*)indexPath {
    UICollectionViewFlowLayout* layout = (UICollectionViewFlowLayout*)collectionViewLayout;
    if ([self sectionIsVisible:indexPath.section]) {
        return layout.itemSize;
    } else {
        return CGSizeMake(layout.itemSize.width, 0.0);
    }
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView
                        layout:(UICollectionViewLayout *)collectionViewLayout
        insetForSectionAtIndex:(NSInteger)section {
    UICollectionViewFlowLayout* layout = (UICollectionViewFlowLayout*)collectionViewLayout;
    if ([self sectionIsVisible:section]) {
        if (section == kStyletFolderIDHistory) {
            UIEdgeInsets insets = layout.sectionInset;
            insets.top = 15.0;
            return insets;
        } else if (section == kStyletFolderIDRecipes
                   && ([self collectionView:collectionView numberOfItemsInSection:section] == 0)) {
            UIEdgeInsets insets = layout.sectionInset;
            insets.top = 8.0;
            return insets;
        } else {
            return layout.sectionInset;
        }
    } else {
        // IMPORTANT: zero-height insets seem to cause the flow layout to
        // just reuse the previously held value of the section insets, so
        // when switching visibility of a section, zero-height insets result
        // in very weird behavior.  Use a "very short" one instead.
        static const UIEdgeInsets epsilon = {0, 0.01, 0.01, 0};
        return epsilon;
    }
}

- (CGFloat)collectionView:(UICollectionView *)collectionView
                   layout:(UICollectionViewLayout *)collectionViewLayout
minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    UICollectionViewFlowLayout* layout = (UICollectionViewFlowLayout*)collectionViewLayout;
    if ([self sectionIsVisible:section]) {
        return layout.minimumLineSpacing;
    } else {
        return 0.0;
    }
}

#pragma mark - LXReorderableCollectionViewDataSource

- (BOOL)collectionView:(UICollectionView *)theCollectionView canMoveItemAtIndexPath:(NSIndexPath *)theIndexPath {
    BOOL retval = NO;
    if (theIndexPath && theIndexPath.section == kStyletFolderIDLibrary) {
        retval = YES;
    }
    return retval;
}

- (void)collectionView:(UICollectionView *)theCollectionView itemAtIndexPath:(NSIndexPath *)fromIndexPath didMoveToIndexPath:(NSIndexPath *)toIndexPath {
    [self.dataController moveStyletAtIndexPath:fromIndexPath toIndexPath:toIndexPath];
}

#pragma mark - UIGestureRecognizerDelegate methods

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)theGestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)theOtherGestureRecognizer {
    // need this because of all the gesture recognizers trying to work around each other
    return YES;
}

#pragma mark - PTGButtonDelegate

- (void)PTGButtonDelegateLongPress:(PTGButton *)sourceButton {
    [self doReset:self];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.alertViewStyle == UIAlertViewStylePlainTextInput) {
        // rename recipe alert shown
        UITextField *alertTextField = [alertView textFieldAtIndex:0];
        if (buttonIndex == 1) {
            // ask the data controller to save the recipe
            NSString* recipeName = alertTextField.text;
            BOOL refreshGrid = [self.dataController renameRecipeAtIndexPath:_savedIndexPath toName:recipeName];
            if (refreshGrid) {
                [self.gridView reloadData];
            }
        }
    } else {
        // unlock filters alert shown
        if (buttonIndex == 1) {
            ThumbnailAttributes* attrs = [self.dataController styletAttributesAtIndexPath:_savedIndexPath];
            [self.dataController unlockRecipeCodeAndFollowURL:attrs.code];
            [self.gridView reloadData];
        }
    }
    _savedIndexPath = nil;
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    BOOL reload = YES;
    
    // save and reset savedIndexPath ASAP; some of the method calls below reuse
    // it for their own purposes.
    NSIndexPath* indexPath = _savedIndexPath;
    _savedIndexPath = nil;
    
    if (buttonIndex == actionSheet.cancelButtonIndex) {
        reload = NO;
    } else if (buttonIndex == actionSheet.destructiveButtonIndex) {
        [self.dataController deleteRecipeAtIndexPath:indexPath];
    } else if (buttonIndex == actionSheet.firstOtherButtonIndex) {
        [self showRenameRecipe:indexPath];
    } else if (buttonIndex == actionSheet.firstOtherButtonIndex + 1) {
        reload = NO;
        [self copyRecipeToClipboard:indexPath];
    } else if (buttonIndex == actionSheet.firstOtherButtonIndex + 2) {
        reload = NO;
        [self emailAllRecipes];
    } else {
        reload = NO;
    }
    if (reload) {
        [self.gridView reloadSections:
         [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(kStyletFolderIDRecipes, kStyletFolderIDHistory)]];
    }
}

#pragma mark - ToolViewControllerDelegate

- (void)doCloseToolView:(ToolViewController *)controller {
    [self dismissViewControllerAnimated:YES completion:NULL];
}

@end
