/**
 * Process refund request (Supabase Edge Function port of functions/src/payments.ts processRefund).
 *
 * Resolves a customer's `refundRequested` order. Only the stall owner or admin may decide.
 */

import { db, bearerUid, err, FieldValue, handle, roleOf, stallOwnerUid } from '../_shared/backend.ts'
import { rateLimit } from '../_shared/security.ts'

Deno.serve((req: Request) =>
  handle(req, async (req) => {
    const uid = await bearerUid(req)
    await rateLimit(uid, 'processRefund', 5)

    const role = await roleOf(uid)
    const data = await req.json()
    const orderId: unknown = data.orderId
    const decision: unknown = data.decision
    if (typeof orderId !== 'string' || orderId.length === 0) {
      throw err('invalid-argument', 'Missing orderId')
    }
    if (decision !== 'approve' && decision !== 'decline') {
      throw err('invalid-argument', 'decision must be "approve" or "decline"')
    }

    const orderRef = db.collection('orders').doc(orderId)
    const orderSnap0 = await orderRef.get()
    if (!orderSnap0.exists) {
      throw err('not-found', 'Order not found')
    }
    const orderData0 = orderSnap0.data()!
    const ownerUid = await stallOwnerUid(orderData0.stallId)
    if (role !== 'admin' && ownerUid !== uid) {
      throw err('permission-denied', 'Only the stall owner or an admin can process this refund request')
    }
    if (orderData0.paymentStatus !== 'refundRequested') {
      throw err('failed-precondition', 'This order has no pending refund request')
    }

    if (decision === 'decline') {
      await releaseRefundRequest(orderRef)
      await orderRef.collection('statusHistory').add({
        orderId,
        previousStatus: orderData0.status,
        newStatus: orderData0.status,
        changedBy: uid,
        changedAt: FieldValue.serverTimestamp(),
        remarks: 'Refund request declined',
      })
      return { processed: 'declined' }
    }

    // Approve: clear the request and return to the refundable `paid` state
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(orderRef)
      if (snap.exists && snap.data()?.paymentStatus === 'refundRequested') {
        tx.update(orderRef, {
          paymentStatus: 'paid',
          updatedAt: FieldValue.serverTimestamp(),
        })
      }
    })

    return { processed: 'approved' }
  }),
)

async function releaseRefundRequest(orderRef: any): Promise<void> {
  // Updates paymentStatus from refundRequested back to paid
  await orderRef.update({
    paymentStatus: 'paid',
    refundRequestReason: null,
    refundRequestedAt: null,
    updatedAt: FieldValue.serverTimestamp(),
  })
}