/**
 * Trusted status transition (Supabase Edge Function port of functions/src/orders.ts updateOrderStatus).
 *
 * - Vendor may advance orders on their own stall.
 * - Customer may cancel their own pending order within the cancel window.
 * - Terminal statuses are immutable; the allowed graph is the single source of truth.
 */

import { db, bearerUid, err, FieldValue, handle, roleOf, isBlocked, stallOwnerUid } from '../_shared/backend.ts'
import { FIELD_LIMITS, CANCELLATION_WINDOW_MS, TERMINAL_STATUSES, canTransition, isCashPayment, validateOptionalText } from '../_shared/constants.ts'
import { rateLimit } from '../_shared/security.ts'

interface TransitionInput {
  orderId: string
  newStatus: string
  remarks: string | null
  estimatedReadyTime?: unknown
}

Deno.serve((req: Request) =>
  handle(req, async (req) => {
    const uid = await bearerUid(req)
    if (await isBlocked(uid)) {
      throw err('permission-denied', 'Your account is blocked')
    }
    await rateLimit(uid, 'orderStatus', 60)

    const data = await req.json()
    const orderId: string | undefined = data.orderId
    const newStatus: string | undefined = data.newStatus
    if (typeof orderId !== 'string') {
      throw err('invalid-argument', 'Missing orderId')
    }
    if (typeof newStatus !== 'string') {
      throw err('invalid-argument', 'Missing newStatus')
    }

    const textError = validateOptionalText(data.remarks, FIELD_LIMITS.remarks, 'remarks')
    if (textError) {
      throw err('invalid-argument', textError)
    }

    const role = await roleOf(uid)
    const orderRef = db.collection('orders').doc(orderId)

    await db.runTransaction(async (tx) => {
      const orderSnap = await tx.get(orderRef)
      if (!orderSnap.exists) {
        throw err('not-found', 'Order not found')
      }
      const order = orderSnap.data()!
      const prevStatus = order.status as string

      if (TERMINAL_STATUSES.has(prevStatus)) {
        throw err('failed-precondition', `Order is already ${prevStatus} and can no longer change`)
      }

      const isReRecord = prevStatus === newStatus
      if (!isReRecord && !canTransition(prevStatus, newStatus)) {
        throw err('failed-precondition', `Illegal transition ${prevStatus} -> ${newStatus}`)
      }

      const ownerUid = await stallOwnerUid(order.stallId as string)

      if (role === 'vendor' || role === 'stall holder' || role === 'admin') {
        if (role !== 'admin' && ownerUid !== uid) {
          throw err('permission-denied', 'Not your stall')
        }
      } else if (role === 'customer') {
        const isCancel = newStatus === 'cancelled'
        const isOwner = order.customerUid === uid
        const now = Date.now()
        const placedAtMs = order.placedAt ? (order.placedAt as any).toMillis?.() ?? Number.NaN : Number.NaN
        const withinWindow = !Number.isNaN(placedAtMs) && now - placedAtMs <= CANCELLATION_WINDOW_MS
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
        status: newStatus,
        updatedAt: FieldValue.serverTimestamp(),
      }

      if (newStatus === 'completed' && isCashPayment(order.paymentMethod ?? 'cod')) {
        update.paymentStatus = 'paid'
      }
      if ((newStatus === 'cancelled' || newStatus === 'rejected') && data.remarks != null) {
        update.cancellationReason = data.remarks
      }
      const isPrivileged = role === 'vendor' || role === 'stall holder' || role === 'admin'
      if (isPrivileged && data.estimatedReadyTime != null) {
        update.estimatedReadyTime = data.estimatedReadyTime
      }

      tx.update(orderRef, update)

      tx.set(orderRef.collection('statusHistory').doc(), {
        orderId,
        previousStatus: prevStatus,
        newStatus,
        changedBy: uid,
        changedAt: FieldValue.serverTimestamp(),
        remarks: data.remarks,
      })

      // Restock on cancellation or rejection
      if (newStatus === 'cancelled' || newStatus === 'rejected') {
        const items = Array.isArray(order.items) ? order.items as Array<{ productId?: string; quantity?: number }> : []
        for (const item of items) {
          if (typeof item.productId !== 'string' || !(typeof item.quantity === 'number' && Number.isFinite(item.quantity)) || item.quantity <= 0) {
            continue
          }
          const productRef = db.collection('vendorStalls').doc(order.stallId as string).collection('products').doc(item.productId)
          tx.update(productRef, { stockQuantity: FieldValue.increment(item.quantity) })
        }
      }
    })

    return { orderId, status: newStatus }
  }),
)