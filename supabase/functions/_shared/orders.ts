/**
 * Trusted status transition (Supabase Edge Functions).
 *
 * Ported from functions/src/orders.ts (applyStatusTransition). In addition,
 * the daily sales rollup (functions/src/sales.ts, a Firestore trigger) runs
 * HERE inside the same transaction when an order flips to `completed`.
 *
 * ponytail: Supabase has no Firestore triggers and the only path to
 * `completed` is this transition, so the rollup folds into it transactionally —
 * no separate sales-rollup function, no loss window. If a second completion
 * path ever appears, extract rollupDaily() behind the transition.
 */

import { db, err, FieldValue, Timestamp, isBlocked, roleOf, stallOwnerUid } from './backend.ts'
import {
  CANCELLATION_WINDOW_MS,
  FIELD_LIMITS,
  isCashPayment,
  OrderStatus,
  TERMINAL_STATUSES,
  canTransition,
  validateOptionalText,
} from './constants.ts'
import { rateLimit } from './security.ts'

export interface TransitionInput {
  orderId: string
  newStatus: OrderStatus
  remarks: string | null
  estimatedReadyTime?: unknown
}

export async function applyStatusTransition(
  uid: string,
  input: TransitionInput,
): Promise<void> {
  if (await isBlocked(uid)) {
    throw err('permission-denied', 'Your account is blocked')
  }
  await rateLimit(db, uid, 'orderStatus', 60)
  const textError = validateOptionalText(input.remarks, FIELD_LIMITS.remarks, 'remarks')
  if (textError) {
    throw err('invalid-argument', textError)
  }
  const role = await roleOf(uid)

  const orderRef = db.collection('orders').doc(input.orderId)
  const orderSnap = await orderRef.get()
  if (!orderSnap.exists) {
    throw err('not-found', 'Order not found')
  }
  const order = orderSnap.data()!
  const prevStatus = order.status as OrderStatus

  if (TERMINAL_STATUSES.has(prevStatus)) {
    throw err(
      'failed-precondition',
      `Order is already ${prevStatus} and can no longer change`,
    )
  }
  // Same-status re-record (e.g. a vendor updating the estimated ready time on
  // an order they are already preparing) is not a transition — it bypasses the
  // graph but still persists the payload fields, mirroring the old client path.
  const isReRecord = prevStatus === input.newStatus
  if (!isReRecord && !canTransition(prevStatus, input.newStatus)) {
    throw err(
      'failed-precondition',
      `Illegal transition ${prevStatus} -> ${input.newStatus}`,
    )
  }

  const ownerUid = await stallOwnerUid(order.stallId)

  // Vendor path.
  if (role === 'vendor' || role === 'stall holder') {
    if (ownerUid !== uid) {
      throw err('permission-denied', 'Not your stall')
    }
  }
  // Customer cancel path.
  else if (role === 'customer') {
    const isCancel = input.newStatus === 'cancelled'
    const isOwner = order.customerUid === uid
    const now = Date.now()
    const placedAtMs =
      order.placedAt instanceof Timestamp ? order.placedAt.toMillis() : Number.NaN
    const withinWindow = !Number.isNaN(placedAtMs) &&
      now - placedAtMs <= CANCELLATION_WINDOW_MS
    if (!isOwner) {
      throw err('permission-denied', 'Not your order')
    }
    if (!isCancel) {
      throw err('permission-denied', 'Customers may only cancel')
    }
    if (!withinWindow) {
      throw err('deadline-exceeded', 'Cancellation window has expired')
    }
  } else {
    throw err('permission-denied', 'You do not have permission')
  }

  const update: Record<string, unknown> = {
    status: input.newStatus,
    updatedAt: FieldValue.serverTimestamp(),
  }
  // Only cash orders (COD / cash on pickup) are marked paid at completion by
  // the vendor. Online methods are flipped to 'paid' exclusively by the
  // verified PayMongo webhook. Legacy orders without a paymentMethod field are
  // treated as cash.
  if (input.newStatus === 'completed' && isCashPayment(order.paymentMethod ?? 'cod')) {
    update.paymentStatus = 'paid'
  }
  if (
    (input.newStatus === 'cancelled' || input.newStatus === 'rejected') &&
    input.remarks != null
  ) {
    update.cancellationReason = input.remarks
  }
  if (input.estimatedReadyTime != null) {
    update.estimatedReadyTime = input.estimatedReadyTime
  }

  await db.runTransaction(async (tx: any) => {
    tx.update(orderRef, update)

    tx.set(orderRef.collection('statusHistory').doc(), {
      orderId: orderRef.id,
      previousStatus: prevStatus,
      newStatus: input.newStatus,
      changedBy: uid,
      changedAt: FieldValue.serverTimestamp(),
      remarks: input.remarks,
    })

    if (input.newStatus === 'completed') {
      await rollupDaily(tx, order)
    }
  })
}

/**
 * Daily sales rollup (ported from functions/src/sales.ts onOrderCompleted).
 * Aggregates revenue into `salesSummary/{stallId}/daily/{YYYY-MM-DD}`; only
 * this trusted path may write salesSummary — the Flutter rules block clients.
 */
async function rollupDaily(tx: any, order: Record<string, any>): Promise<void> {
  const stallId: string | undefined = order.stallId
  const placedAt =
    order.placedAt instanceof Timestamp ? order.placedAt.toDate() : new Date()
  if (typeof stallId !== 'string') {
    return
  }
  const itemsTotal = Array.isArray(order.items)
    ? (order.items as Array<{ unitPrice?: number; quantity?: number }>).reduce(
        (sum, i) => sum + (i.unitPrice ?? 0) * (i.quantity ?? 0),
        0,
      )
    : 0
  const revenue =
    itemsTotal +
    (typeof order.deliveryFee === 'number' ? order.deliveryFee : 0) +
    (typeof order.serviceFee === 'number' ? order.serviceFee : 0) +
    (typeof order.priorityFee === 'number' ? order.priorityFee : 0)

  const dateKey = placedAt.toISOString().split('T')[0]
  const dailyRef = db.collection('salesSummary').doc(stallId).collection('daily').doc(dateKey)

  const snap = await tx.get(dailyRef)
  const prev = snap.exists ? snap.data() ?? {} : {}
  tx.set(dailyRef, {
    date: dateKey,
    totalRevenue: (typeof prev.totalRevenue === 'number' ? prev.totalRevenue : 0) + revenue,
    orderCount: (typeof prev.orderCount === 'number' ? prev.orderCount : 0) + 1,
  })
}
