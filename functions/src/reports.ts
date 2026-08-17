import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';

const db = admin.firestore();

/**
 * Vendor sales report (ownership-gated).
 * Returns the raw completed-order records for a stall within a date range.
 * Revenue figures here back the in-app PDF/Excel reports (Phase 7) so the
 * document always reflects real, completed transactions under the vendor's
 * own authority.
 */
export const getSalesReport = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in required');
  }

  const data = request.data ?? {};
  const stallId: unknown = data.stallId;
  const from: unknown = data.from;
  const to: unknown = data.to;

  if (
    typeof stallId !== 'string' ||
    typeof from !== 'string' ||
    typeof to !== 'string'
  ) {
    throw new HttpsError('invalid-argument', 'stallId, from, to required');
  }

  const stallSnap = await db.collection('vendorStalls').doc(stallId).get();
  if (!stallSnap.exists || stallSnap.data()?.ownerUid !== uid) {
    throw new HttpsError('permission-denied', 'Not your stall');
  }

  const fromDate = new Date(from);
  const toDate = new Date(to);
  if (Number.isNaN(fromDate.getTime()) || Number.isNaN(toDate.getTime())) {
    throw new HttpsError('invalid-argument', 'Invalid date range');
  }

  const snap = await db
    .collection('orders')
    .where('stallId', '==', stallId)
    .where('status', '==', 'completed')
    .where('placedAt', '>=', fromDate)
    .where('placedAt', '<=', toDate)
    .orderBy('placedAt', 'asc')
    .get();

  const report = snap.docs.map((doc) => {
    const d = doc.data();
    const itemsTotal = Array.isArray(d.items)
      ? (d.items as Array<{ unitPrice?: number; quantity?: number }>).reduce(
          (sum, i) => sum + (i.unitPrice ?? 0) * (i.quantity ?? 0),
          0,
        )
      : 0;
    return {
      orderId: doc.id,
      placedAt: d.placedAt instanceof admin.firestore.Timestamp
        ? d.placedAt.toMillis()
        : null,
      items: d.items ?? [],
      revenue:
        itemsTotal +
        (typeof d.deliveryFee === 'number' ? d.deliveryFee : 0) +
        (typeof d.serviceFee === 'number' ? d.serviceFee : 0) +
        (typeof d.priorityFee === 'number' ? d.priorityFee : 0),
    };
  });

  return { stallId, from: fromDate.toISOString(), to: toDate.toISOString(), report };
});