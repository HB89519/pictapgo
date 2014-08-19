//
//  MKStoreManager.m
//
//  Created by Mugunth Kumar on 17-Oct-09.
//  Copyright 2009 Mugunth Kumar. All rights reserved.
//  mugunthkumar.com
//

#import "MKStoreManager.h"

@implementation MKStoreManager

@synthesize purchasableObjects;
@synthesize storeObserver;
@synthesize delegate;

// all your features should be managed one and only by StoreManager
static NSString *feature1 = @"pictapgo.replichrome";
static NSString *feature2 = @"pictapgo.feature2";

BOOL featurePurchased1;
BOOL featurePurchased2;

static MKStoreManager* _sharedStoreManager; // self

- (void)dealloc {
	[_sharedStoreManager release];
	[storeObserver release];
    
	[super dealloc];
}

+ (BOOL) featurePurchased1
{
    return featurePurchased1;
}

+ (BOOL) featurePurchased2
{
    return featurePurchased2;
}

+ (MKStoreManager*)sharedManager
{
	@synchronized(self) {
		
        if (_sharedStoreManager == nil) {
			
            _sharedStoreManager = [[self alloc] init]; // assignment not done here
			_sharedStoreManager.purchasableObjects = [[NSMutableArray alloc] init];			
			[_sharedStoreManager requestProductData];
            
			_sharedStoreManager.storeObserver = [[MKStoreObserver alloc] init];
			[[SKPaymentQueue defaultQueue] addTransactionObserver:_sharedStoreManager.storeObserver];
        }
    }
    return _sharedStoreManager;
}


- (void) requestProductData
{
	SKProductsRequest *request= [[SKProductsRequest alloc] initWithProductIdentifiers: 
								 [NSSet setWithObjects: feature1, feature2, nil]]; // add any other product here
	request.delegate = self;
	[request start];
}


- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
	[purchasableObjects addObjectsFromArray:response.products];
    
	// populate your UI Controls here
	for(int i=0;i<[purchasableObjects count];i++)
	{
		
		SKProduct *product = [purchasableObjects objectAtIndex:i];
		NSLog(@"Feature: %@, Cost: %f, ID: %@",[product localizedTitle],
			  [[product price] doubleValue], [product productIdentifier]);  
	}
		
	[request autorelease];
}

- (void) buyFeature:(NSString*) featureId
{
	if ([SKPaymentQueue canMakePayments])
	{
		SKPayment *payment = [SKPayment paymentWithProductIdentifier:featureId];
		[[SKPaymentQueue defaultQueue] addPayment:payment];
	}
	else
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Warning" message:@"You are not authorized to purchase from AppStore"
													   delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil];
		[alert show];
		[alert release];
	}
}

- (void) buyFeature1
{
	[self buyFeature:feature1];
}

- (void) buyFeature2
{
	[self buyFeature:feature2];
}

- (void)restoreAllPurchases
{
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

- (void) restorePurchases:(NSString*) productIdentifier {
    if ([productIdentifier isEqualToString:feature1]) {
        featurePurchased1 = YES;
    }
    else if ([productIdentifier isEqualToString:feature2]) {
        featurePurchased2 = YES;
    }
}

- (void) canceledTransaction
{
    if ([delegate respondsToSelector:@selector(didCancelProduct)]) {
        [delegate performSelector:@selector(didCancelProduct)];
    }
}

- (void) failedTransaction: (SKPaymentTransaction *)transaction
{
    if (transaction.error.code != SKErrorPaymentCancelled){		
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Purchase request failed" message:@"Please check your Internet connection and your App Store account information." delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil];
		[alert show];
		[alert release];
        if ([delegate respondsToSelector:@selector(didFailProductWithError:)]) {
            [delegate performSelector:@selector(didFailProductWithError:) withObject:transaction.error];
        }
    }
    else {
        if ([delegate respondsToSelector:@selector(didCancelProduct)]) {
            [delegate performSelector:@selector(didCancelProduct)];
        }
    }
	
	NSString *msg = [NSString stringWithFormat:@"Reason: %@, You can try: %@", [transaction.error localizedFailureReason], [transaction.error localizedRecoverySuggestion]];
	NSLog(@"In App purchase failed\n%@", msg);
}

-(void) provideContent: (NSString*) productIdentifier
{
	if([productIdentifier isEqualToString:feature1])
	{
        featurePurchased1 = YES;
        if ([delegate respondsToSelector:@selector(didBuyProduct1)]) {
            [delegate performSelector:@selector(didBuyProduct1)];
        }
    }
    else if([productIdentifier isEqualToString:feature2])
	{
        featurePurchased2 = YES;
        if ([delegate respondsToSelector:@selector(didBuyProduct2)]) {
            [delegate performSelector:@selector(didBuyProduct2)];
        }
    }

    [MKStoreManager updatePurchases];
}

+(void) loadPurchases 
{
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];	
	featurePurchased1 = [userDefaults boolForKey:feature1];
    featurePurchased2 = [userDefaults boolForKey:feature2];
}

+(void) updatePurchases
{
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	[userDefaults setBool:featurePurchased1 forKey:feature1];
    [userDefaults setBool:featurePurchased2 forKey:feature2];

    [userDefaults synchronize];
}


@end
