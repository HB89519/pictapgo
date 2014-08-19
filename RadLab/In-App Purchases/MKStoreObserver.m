//
//  MKStoreObserver.m
//
//  Created by Mugunth Kumar on 17-Oct-09.
//  Copyright 2009 Mugunth Kumar. All rights reserved.
//

#import "MKStoreObserver.h"
#import "MKStoreManager.h"

@implementation MKStoreObserver

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions
{
	for (SKPaymentTransaction *transaction in transactions)
	{
		switch (transaction.transactionState)
		{
			case SKPaymentTransactionStatePurchased:
				
                [self completeTransaction:transaction];
				
                break;
				
            case SKPaymentTransactionStateFailed:
				
                [self failedTransaction:transaction];
				
                break;
				
            case SKPaymentTransactionStateRestored:
				
                [self restoreTransaction:transaction];
				
            default:
				
                break;
		}			
	}
}
- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error
{
    if (error.code == SKErrorPaymentCancelled || error.code == SKErrorUnknown) {
        [[MKStoreManager sharedManager] canceledTransaction];
    }
    
    UIAlertView *failedAlert = [[UIAlertView alloc] initWithTitle:@"Restore Stopped" message:@"Either you cancelled the request or your prior purchase could not be restored. Please try again later, or contact the app's customer support for assistance." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [failedAlert show];
    [failedAlert release];
}

- (void) failedTransaction: (SKPaymentTransaction *)transaction{	
	NSLog(@"Failed - Observer");
    [[MKStoreManager sharedManager] failedTransaction:transaction];
    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];	
}

- (void) completeTransaction: (SKPaymentTransaction *)transaction
{		
	NSLog(@"Completed - Observer");
    [[MKStoreManager sharedManager] provideContent: transaction.payment.productIdentifier];	
    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];	
}

- (void) restoreTransaction: (SKPaymentTransaction *)transaction
{	
	NSLog(@"Restored - Observer");
    [[MKStoreManager sharedManager] provideContent: transaction.originalTransaction.payment.productIdentifier];	
    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];	
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    
    NSLog(@"paymentQueueRestoreCompletedTransactionsFinished");
    if ([queue.transactions count] == 0) {
        // Queue does not include any transactions, so either user has not yet made a purchase
        // or the user's prior purchase is unavailable, so notify app (and user) accordingly.
        
        NSLog(@" restore queue.transactions count == 0");
        
        // Release the transaction observer since no prior transactions were found.
        [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
        
        [self incompleteRestore];
        
    } else{
        
        for (SKPaymentTransaction *transaction in queue.transactions)
        {
            
            [[MKStoreManager sharedManager]  provideContent: transaction.originalTransaction.payment.productIdentifier];
            [[MKStoreManager sharedManager] restorePurchases:transaction.payment.productIdentifier];
            [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
            NSLog (@"product id is %@" , transaction.originalTransaction.payment.productIdentifier);
            // here put an if/then statement to write files based on previously purchased items
            // example if ([productID isequaltostring: @"youruniqueproductidentifier]){write files} else { nslog sorry}
        }
    }
}

- (void) incompleteRestore
{
    NSLog(@"ViewController incompleteRestore");
    
    // Restore queue did not include any transactions, so either the user has not yet made a purchase
    // or the user's prior purchase is unavailable, so notify user to make a purchase within the app.
    // If the user previously purchased the item, they will NOT be re-charged again, but it should
    // restore their purchase.
    
    UIAlertView *restoreAlert = [[UIAlertView alloc] initWithTitle:@"Restore Issue" message:@"A prior purchase transaction could not be found. To restore the purchased product, tap the Buy button. Paid customers will NOT be charged again, but the purchase will be restored." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [restoreAlert show];
    [restoreAlert release];
}

@end
