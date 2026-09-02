import { onDocumentUpdated } from 'firebase-functions/v2/firestore';
import * as admin from 'firebase-admin';
import { Timestamp } from 'firebase-admin/firestore';

const db = admin.firestore();

/**
 * Daily sales rollup.
 * When an order transitions to `completed`, aggregate its revenue into
 * `salesSummary/{stallId}/daily/{YYYY-MM-DD}`. Only the trusted trigger may
 * write salesSummary — the Flutter rules block client writes entirely.
 */
export const onOrderCompleted = onDocumentUpdated(
  'orders/{orderId}',
  async (event) => {
    const before = event.data?.before;
    const after = event.data?.after;
    if (!after) {
      return;
    }
    const data = after.data();

    if (!data) {
      return;
    }
    if (before?.data()?.status !== 'completed' && data.status === 'completed') {
      const stallId: string | undefined = data.stallId;
      const placedAt =
        data.placedAt instanceof Timestamp
          ? data.placedAt.toDate()
          : new Date();
      if (typeof stallId !== 'string') {
        return;
      }
      const itemsTotal = Array.isArray(data.items)
        ? (data.items as Array<{ unitPrice?: number; quantity?: number }>).reduce(
            (sum, i) => sum + (i.unitPrice ?? 0) * (i.quantity ?? 0),
            0,
          )
        : 0;
      const revenue =
        itemsTotal +
        (typeof data.deliveryFee === 'number' ? data.deliveryFee : 0) +
        (typeof data.serviceFee === 'number' ? data.serviceFee : 0) +
        (typeof data.priorityFee === 'number' ? data.priorityFee : 0);

      // Bucket by Philippine calendar day (Asia/Manila, UTC+8) — the vendor
      // earnings screen queries by local date strings. The old UTC bucketing
      // (toISOString) put orders placed 00:00–08:00 PHT into the PREVIOUS
      // day's rollup (audit 2026-08-23 L1). 'en-CA' emits YYYY-MM-DD.
      // NOTE: historical rows written before this change remain under UTC
      // keys; a one-off backfill is needed if old daily totals matter.
      const dateKey = new Intl.DateTimeFormat('en-CA', {
        timeZone: 'Asia/Manila',
      }).format(placedAt);
      const dailyRef = db
        .collection('salesSummary')
        .doc(stallId)
        .collection('daily')
        .doc(dateKey);

      await db.runTransaction(async (tx) => {
        const snap = await tx.get(dailyRef);
        const prev = snap.exists ? snap.data() ?? {} : {};
        await tx.set(
          dailyRef,
          {
            date: dateKey,
            totalRevenue:
              (typeof prev.totalRevenue === 'number' ? prev.totalRevenue : 0) +
              revenue,
            orderCount:
              (typeof prev.orderCount === 'number' ? prev.orderCount : 0) + 1,
          },
        );
      });
    }
  },
);