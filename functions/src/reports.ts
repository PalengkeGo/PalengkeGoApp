import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { Timestamp } from 'firebase-admin/firestore';
import { APP_CHECK_ENFORCED, rateLimit } from './security';

const db = admin.firestore();

/**
 * Vendor sales report (ownership-gated).
 * Returns the raw completed-order records for a stall within a date range.
 * Revenue figures here back the in-app PDF/Excel reports (Phase 7) so the
 * document always reflects real, completed transactions under the vendor's
 * own authority.
 */
export const getSalesReport = onCall(
  { enforceAppCheck: APP_CHECK_ENFORCED },
  async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in required');
  }
  await rateLimit(uid, 'salesReport', 10);

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

  const callerRole = (await db.collection('users').doc(uid).get()).data()?.role;
  const stallSnap = await db.collection('vendorStalls').doc(stallId).get();
  // The stall owner or an admin (market-wide revenue reports for the
  // Admin Web portal) may pull the report.
  if (!stallSnap.exists ||
      (stallSnap.data()?.ownerUid !== uid && callerRole !== 'admin')) {
    throw new HttpsError('permission-denied', 'Not your stall');
  }

  const fromDate = new Date(from);
  const toDate = new Date(to);
  if (Number.isNaN(fromDate.getTime()) || Number.isNaN(toDate.getTime())) {
    throw new HttpsError('invalid-argument', 'Invalid date range');
  }

  // Audit 2026-08-23 L2: a date-only `to` (YYYY-MM-DD) parses as the START
  // of that day, silently excluding the whole end date. Treat date-only `to`
  // as inclusive of the entire day.
  const DATE_ONLY = /^\d{4}-\d{2}-\d{2}$/;
  const toInclusive = DATE_ONLY.test(to);
  const toBound = toInclusive
    ? new Date(toDate.getTime() + 24 * 60 * 60 * 1000)
    : toDate;

  // Cap the range so a single call cannot scan/return an unbounded number of
  // orders (callable responses and Firestore reads are finite resources).
  const MAX_RANGE_MS = 366 * 24 * 60 * 60 * 1000;
  if (toBound.getTime() - fromDate.getTime() > MAX_RANGE_MS) {
    throw new HttpsError(
      'invalid-argument',
      'Date range is too large (max 366 days)',
    );
  }
  if (toBound.getTime() < fromDate.getTime()) {
    throw new HttpsError('invalid-argument', 'Invalid date range');
  }

  const snap = await db
    .collection('orders')
    .where('stallId', '==', stallId)
    .where('status', '==', 'completed')
    .where('placedAt', '>=', fromDate)
    .where('placedAt', toInclusive ? '<' : '<=', toBound)
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
      placedAt: d.placedAt instanceof Timestamp
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