import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { FieldValue } from 'firebase-admin/firestore';
import { FIELD_LIMITS, validateOptionalText } from './constants';
import { APP_CHECK_ENFORCED, rateLimit } from './security';

const db = admin.firestore();

/**
 * Trusted review creation.
 *
 * The customer must be the owner of a completed order for the vendor. The
 * stall rating aggregate is recomputed in the SAME transaction so the
 * average/count can never drift from the raw review set.
 *
 * One-review-per-order is enforced WITHOUT a query-then-write race: the rating
 * doc id is deterministic (`ratings/{orderId}_{customerId}`), and the doc is
 * created inside the transaction only if it does not already exist. Two
 * concurrent submissions collide on the same id — one commits, the other sees
 * the existing doc and is rejected.
 */
export const addReview = onCall(
  { enforceAppCheck: APP_CHECK_ENFORCED },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Sign in required');
    }
    await rateLimit(uid, 'addReview', 10);

    const data = request.data ?? {};
    const stallId: unknown = data.stallId;
    const orderId: unknown = data.orderId;
    const rating: unknown = data.rating;
    const comment: string | undefined = data.comment;
    const reviewType: string | undefined = data.reviewType;
    const productId: string | undefined = data.productId;
    const productName: string | undefined = data.productName;

    if (typeof stallId !== 'string' || typeof orderId !== 'string') {
      throw new HttpsError('invalid-argument', 'stallId and orderId required');
    }
    if (
      typeof rating !== 'number' ||
      rating < 1 ||
      rating > 5 ||
      !Number.isInteger(rating * 10)
    ) {
      throw new HttpsError('invalid-argument', 'rating must be 1..5 (0.1 steps)');
    }
    const textError =
      validateOptionalText(comment, FIELD_LIMITS.reviewComment, 'comment') ??
      validateOptionalText(
        productName,
        FIELD_LIMITS.reviewProductName,
        'productName',
      ) ??
      validateOptionalText(
        data.customerName,
        FIELD_LIMITS.customerName,
        'customerName',
      );
    if (textError) {
      throw new HttpsError('invalid-argument', textError);
    }

    // Verify the order belongs to this customer and is completed.
    const orderSnap = await db.collection('orders').doc(orderId).get();
    if (!orderSnap.exists) {
      throw new HttpsError('not-found', 'Order not found');
    }
    const order = orderSnap.data()!;
    if (order.customerUid !== uid) {
      throw new HttpsError('permission-denied', 'Not your order');
    }
    if (order.stallId !== stallId) {
      throw new HttpsError('invalid-argument', 'Order does not belong to this stall');
    }
    if (order.status !== 'completed') {
      throw new HttpsError(
        'failed-precondition',
        'Only completed orders can be reviewed',
      );
    }

    // Fast pre-check for reviews written before deterministic ids existed
    // (legacy random-id docs). The authoritative check is the transactional
    // create below.
    const legacy = await db
      .collection('ratings')
      .where('orderId', '==', orderId)
      .where('customerId', '==', uid)
      .limit(1)
      .get();
    if (!legacy.empty) {
      throw new HttpsError('already-exists', 'This order was already reviewed');
    }

    // Deterministic id: one review per (order, customer) is guaranteed by the
    // document identity itself, not by a check-then-write sequence.
    const ratingRef = db.collection('ratings').doc(`${orderId}_${uid}`);

    await db.runTransaction(async (tx) => {
      const existing = await tx.get(ratingRef);
      if (existing.exists) {
        throw new HttpsError(
          'already-exists',
          'This order was already reviewed',
        );
      }

      // Lock the stall doc: read + write in the same transaction.
      const stallRef = db.collection('vendorStalls').doc(stallId);
      const stallSnap = await tx.get(stallRef);
      const stall = stallSnap.exists ? stallSnap.data() ?? {} : {};
      const currentRating = typeof stall.averageRating === 'number'
        ? stall.averageRating
        : 0;
      const currentCount = typeof stall.totalRatings === 'number'
        ? stall.totalRatings
        : 0;

      const newCount = currentCount + 1;
      const newAverage =
        (currentRating * currentCount + rating) / newCount;

      await tx.set(ratingRef, {
        vendorId: stallId,
        customerId: uid,
        customerName: data.customerName ?? 'Customer',
        rating,
        comment: comment ?? '',
        date: FieldValue.serverTimestamp(),
        orderId,
        reviewType: reviewType === 'product' ? 'product' : 'vendor',
        productName: productName ?? null,
      });

      await tx.update(stallRef, {
        averageRating: newAverage,
        totalRatings: newCount,
      });
    });

    return { ratingId: ratingRef.id };
  },
);
