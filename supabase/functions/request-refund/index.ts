/**
 * Customer refund request (Supabase Edge Function port of functions/src/payments.ts requestRefund).
 *
 * Flips a paid order to `refundRequested` and records the reason.
 */

import { db, bearerUid, err, FieldValue, handle } from '../_shared/backend.ts'
import { FIELD_LIMITS, validateOptionalText } from '../_shared/constants.ts'
import { rateLimit } from '../_shared/security.ts'

Deno.serve((req: Request) =>
  handle(req, async (req) => {
    const uid = await bearerUid(req)
    await rateLimit(uid, 'requestRefund', 5)

    const data = await req.json()
    const orderId: unknown = data.orderId
    if (typeof orderId !== 'string' || orderId.length === 0) {
      throw err('invalid-argument', 'Missing orderId')
    }

    const reasonError = validateOptionalText(data.reason, FIELD_LIMITS.refundReason, 'reason')
    if (reasonError) {
      throw err('invalid-argument', reasonError)
    }

    const orderRef = db.collection('orders').doc(orderId)
    let orderStatus = 'pending'

    await db.runTransaction(async (tx) => {
      const snap = await tx.get(orderRef)
      if (!snap.exists) {
        throw err('not-found', 'Order not found')
      }
      const order = snap.data()!
      if (order.customerUid !== uid) {
        throw err('permission-denied', 'Not your order')
      }
      if (order.paymentStatus !== 'paid') {
        throw err('failed-precondition', 'Only fully or partially paid orders can be refunded')
      }
      orderStatus = typeof order.status === 'string' ? order.status : 'pending'
      tx.update(orderRef, {
        paymentStatus: 'refundRequested',
        refundRequestReason: typeof data.reason === 'string' ? data.reason : null,
        refundRequestedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      })
    })

    await orderRef.collection('statusHistory').add({
      orderId,
      previousStatus: orderStatus,
      newStatus: orderStatus,
      changedBy: uid,
      changedAt: FieldValue.serverTimestamp(),
      remarks: 'Refund requested by customer',
    })

    return { requested: true }
  }),
)