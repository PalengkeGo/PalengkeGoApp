/**
 * Minimal cancel helper for the cancel-order edge function.
 * Mirrors the customer cancel branch of update-order-status.
 */

import { db, err, FieldValue } from '../_shared/backend.ts'
import { CANCELLATION_WINDOW_MS } from '../_shared/constants.ts'

export async function applyCancelTransition(
  uid: string,
  orderId: string,
  reason: string | null,
): Promise<void> {
  const orderRef = db.collection('orders').doc(orderId)
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(orderRef)
    if (!snap.exists) throw err('not-found', 'Order not found')
    const order = snap.data()!
    if (order.status !== 'pending') {
      throw err('failed-precondition', 'Only pending orders can be cancelled')
    }
    if (order.customerUid !== uid) throw err('permission-denied', 'Not your order')
    const placedAtMs = (order.placedAt as any)?.toMillis?.() as number | undefined
    const withinWindow =
      typeof placedAtMs === 'number' && Date.now() - placedAtMs <= CANCELLATION_WINDOW_MS
    if (!withinWindow) throw err('deadline-exceeded', 'Cancellation window has expired')

    tx.update(orderRef, {
      status: 'cancelled',
      cancellationReason: reason,
      updatedAt: FieldValue.serverTimestamp(),
    })
    tx.set(orderRef.collection('statusHistory').doc(), {
      orderId,
      previousStatus: 'pending',
      newStatus: 'cancelled',
      changedBy: uid,
      changedAt: FieldValue.serverTimestamp(),
      remarks: reason,
    })
    // Restock
    const items = Array.isArray(order.items) ? order.items as Array<{ productId?: string; quantity?: number }> : []
    for (const item of items) {
      if (typeof item.productId !== 'string' || typeof item.quantity !== 'number' || !Number.isFinite(item.quantity) || item.quantity <= 0) continue
      const ref = db.collection('vendorStalls').doc(order.stallId as string).collection('products').doc(item.productId)
      tx.update(ref, { stockQuantity: FieldValue.increment(item.quantity) })
    }
  })
}
