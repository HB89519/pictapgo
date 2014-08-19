//
//  StoreManager.h
//  MKSync
//
//  Created by Mugunth Kumar on 17-Oct-09.
//  Copyright 2009 MK Inc. All rights reserved.
//  mugunthkumar.com

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>
#import "MKStoreObserver.h"

@protocol MKStoreManagerDelegate <NSObject>

- (void)didBuyProduct1;
- (void)didBuyProduct2;
- (void)didCancelProduct;
- (void)didFailProductWithError:(NSError *) error;

@end


@interface MKStoreManager : NSObject<SKProductsRequestDelegate> {
    
	NSMutableArray *purchasableObjects;
	MKStoreObserver *storeObserver;		
}

@property (nonatomic, retain) NSMutableArray *purchasableObjects;
@property (nonatomic, retain) MKStoreObserver *storeObserver;
@property (nonatomic, retain) id<MKStoreManagerDelegate> delegate;

- (void) requestProductData;
- (void)restoreAllPurchases;

- (void) canceledTransaction;
- (void) failedTransaction: (SKPaymentTransaction *)transaction;
-(void) provideContent: (NSString*) productIdentifier;

+ (MKStoreManager*)sharedManager;

+ (BOOL) featurePurchased1;
+ (BOOL) featurePurchased2;

- (void) buyFeature1;
- (void) buyFeature2;
- (void) restorePurchases:(NSString*) productIdentifier;

+(void) loadPurchases;
+(void) updatePurchases;

@end
