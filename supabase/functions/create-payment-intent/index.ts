/**
 * Create Payment Intent (Supabase Edge Function port of functions/src/payments.ts createPaymentIntent).
 *
 * Server-side amount computation + PayMongo limits. Atomic claim prevents duplicate intents.
 */

import { db, bearerUid, err, FieldValue, handle, roleOf } from '../_shared/backend.ts'
import { rateLimit, PAYMONGO_SECRET_KEY } from '../_shared/constants.ts'
import { rateLimit as rateL } from '../_shared/security.ts'
import { normalizePaymentMethod, computeOrderAmountCents } from '../_shared/logic.ts'

Deno.serve((req: Request) =>
  handle(req, async (req) => {
    const uid = await bearerUid(req)
    const role = await roleOf(uid)
    if (role !== 'customer') {
      throw err('permission-denied', 'Only customers can pay')
    }
    await rateL(uid, 'createPaymentIntent', 10)

    const data = await req.json()
    const orderId: unknown = data.orderId
    const method = normalizePaymentMethod(data.paymentMethod)
    if (typeof orderId !== 'string' || orderId.length === 0) {
      throw err('invalid-argument', 'Missing orderId')
    }
    if (!method) {
      throw err('invalid-argument', 'paymentMethod must be one of: card, gcash, maya')
    }

    const secretKey = Deno.env.get('PAYMONGO_SECRET_KEY')
    if (!secretKey) {
      throw err('failed-precondition', 'PayMongo is not configured on the backend')
    }

    const orderRef = db.collection('orders').doc(orderId)
    const claim: { outcome: 'claimed' | 'inspect-intent' | 'fresh-intent' } = { outcome: 'claimed' }
    const order: Record<string, unknown> = await db.runTransaction(async (tx) => {
      const orderSnap = await tx.get(orderRef)
      if (!orderSnap.exists) {
        throw err('not-found', 'Order not found')
      }
      const order = orderSnap.data()!
      if (order.customerUid !== uid) {
        throw err('permission-denied', 'Not your order')
      }
      if (order.status !== 'pending') {
        throw err('failed-precondition', 'Only pending orders can be paid')
      }
      if (order.paymentStatus === 'paid') {
        throw err('already-exists', 'Order is already paid')
      }
      if (order.paymentStatus === 'processing') {
        const updatedAtMs = (order.updatedAt as any)?.toMillis?.() ?? undefined
        const decision = claimDecision(order.paymentIntentId, updatedAtMs, Date.now())
        if (decision === 'fresh-processing') {
          throw err('failed-precondition', 'A payment is already in progress for this order')
        }
        claim.outcome = decision
      }

      tx.update(orderRef, { paymentStatus: 'processing', updatedAt: FieldValue.serverTimestamp() })
      return order
    })

    if (claim.outcome === 'inspect-intent') {
      const staleIntentId = order.paymentIntentId as string
      const intent = await retrieveIntent(staleIntentId, secretKey)
      const status = intent?.attributes?.status
      if (status === 'succeeded') {
        const lastPayment = intent?.attributes?.last_payment
        const paymentId = typeof lastPayment === 'string'
          ? lastPayment
          : (typeof lastPayment === 'object' && lastPayment !== null ? lastPayment.id ?? null : null)
        await orderRef.update({
          paymentStatus: 'paid',
          paidAt: FieldValue.serverTimestamp(),
          paymentId,
          updatedAt: FieldValue.serverTimestamp(),
        })
        throw err('already-exists', 'Order is already paid')
      }
      if (status !== 'canceled') {
        throw err('failed-precondition', 'A payment is still pending for this order — complete or cancel it in your e-wallet app, or contact the stall')
      }
    }

    const amountCents = computeOrderAmountCents(order)
    if (amountCents < 100) {
      await releaseClaim(orderRef)
      throw err('out-of-range', 'Amount must be at least PHP 1.00')
    }

    // TODO: Call PayMongo API to create intent and return intentId + clientKey
    // For now, just return a stub so the edge function is deployable
    return { intentId: 'pi_staging_' + orderId, clientKey: 'sk_staging_' + orderId }
  }),
)

function claimDecision(intentId: unknown, updatedAtMs: number | undefined, nowMs: number): 'fresh-processing' | 'inspect-intent' {
  // Stale claim (>10 minutes) → inspect the existing intent
  if (updatedAtMs === undefined || nowMs - updatedAtMs > 10 * 60 * 1000) {
    return 'inspect-intent'
  }
  // Fresh claim → reject to prevent duplicate intents
  return 'fresh-processing'
}

async function retrieveIntent(intentId: string, secretKey: string): Promise<any | null> {
  // Mock implementation — replace with actual PayMoney API call
  return null
}

async function releaseClaim(orderRef: any): Promise<void> {
  await orderRef.update({
    paymentStatus: 'pending',
    updatedAt: FieldValue.serverTimestamp(),
  })
}