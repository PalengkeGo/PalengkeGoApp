import * as admin from 'firebase-admin';
import { setGlobalOptions } from 'firebase-functions/v2';

admin.initializeApp();
setGlobalOptions({ region: 'asia-southeast1' });

export { placeOrder, updateOrderStatus, cancelOrder } from './orders';
export { addReview } from './reviews';
export { getSalesReport } from './reports';
export { onOrderCompleted } from './sales';
export { createPaymentIntent, paymongoWebhook, createRefund } from './payments';
export { approveKyc, approveRenewal, setAccountBlocked } from './admin';
