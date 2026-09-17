/**
 * Trusted payment intent creation (ported from functions/src/payments.ts createPaymentIntent).
 */
import { bearerUid, db, err, FieldValue, handle, isBlocked, rateLimit, Timestamp } from '../_shared/backend.ts'
import { PAYMONGO_API_URL } from '../_shared/constants.ts'
import { claimDecision, computeOrderAmountCents, normalizePaymentMethod } from '../_shared/logic.ts'

Deno.serve((req: Request) =>
  handle(req, async (req) => {
    const uid = await bearerUid(req, true)
    if (await isBlocked(uid)) throw err('permission-denied', 'Your account is blocked')
    await rateLimit(db, uid, 'createPaymentIntent', 10)

    const data = await req.json().catch(() => ({}))
    const orderId: unknown = data.orderId
    const method = normalizePaymentMethod(data.paymentMethod)
    if (typeof orderId !== 'string' || orderId.length === 0) throw err('invalid-argument', 'Missing orderId')
    if (!method) throw err('invalid-argument', 'paymentMethod must be one of: card, gcash, maya')

    const secretKey = Deno.env.get('PAYMONGO_SECRET_KEY')
    if (!secretKey) throw err('failed-precondition', 'PayMongo is not configured on the backend')

    const orderRef = db.collection('orders').doc(orderId)
    const claim: { outcome: 'claimed' | string } = { outcome: 'claimed' }

    const order: Record<string, unknown> = await db.runTransaction(async (tx) => {
      const orderSnap = await tx.get(orderRef)
      if (!orderSnap.exists) throw err('not-found', 'Order not found')
      const order = orderSnap.data()!

      if (order.customerUid !== uid) throw err('permission-denied', 'Not your order')
      if (order.status !== 'pending') throw err('failed-precondition', 'Only pending orders can be paid')
      if (order.paymentStatus === 'paid') throw err('already-exists', 'Order is already paid')
      if (order.paymentStatus === 'processing') {
        const updatedAtMs =
          order.updatedAt instanceof Timestamp
            ? order.updatedAt.toMillis()
            : order.updatedAt instanceof Date
            ? order.updatedAt.getTime()
            : undefined
        const decision = claimDecision(order.paymentIntentId, updatedAtMs, Date.now())
        if (decision === 'fresh-processing') throw err('failed-precondition', 'A payment is already in progress')
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
        const paymentId = typeof lastPayment === 'string' ? lastPayment : (typeof lastPayment === 'object' && lastPayment !== null ? lastPayment.id ?? null : null)
        await orderRef.update({ paymentStatus: 'paid', paidAt: FieldValue.serverTimestamp(), paymentId, updatedAt: FieldValue.serverTimestamp() })
        throw err('already-exists', 'Order is already paid')
      }
      if (status !== 'canceled') throw err('failed-precondition', 'Payment pending — complete or cancel in e-wallet app')
    }

    const amountCents = computeOrderAmountCents(order)
    if (amountCents < 100) { await releaseClaim(orderRef); throw err('invalid-argument', 'Order total below PHP 1.00 minimum') }
    if (method !== 'card' && amountCents > 10_000_000) { await releaseClaim(orderRef); throw err('invalid-argument', 'E-wallet capped at PHP 100,000') }
    if (method === 'card' && amountCents >= 1_000_000_000) { await releaseClaim(orderRef); throw err('invalid-argument', 'Card must be below PHP 10,000,000') }

    let intentId: string | undefined
    let clientKey: string | undefined
    try {
      const response = await fetch(`${PAYMONGO_API_URL}/payment_intents`, {
        method: 'POST',
        headers: {
          Authorization: `Basic ${btoa(`${secretKey}:`)}`,
          'Content-Type': 'application/json',
          'Idempotency-Key': crypto.randomUUID(),
        },
        body: JSON.stringify({
          data: { attributes: { amount: amountCents, currency: 'PHP', payment_method_allowed: ['card', 'gcash', 'maya'], description: `Order #${orderId}`, metadata: { orderId } } },
        }),
      })

      const payload: unknown = await response.json().catch(() => null)
      if (!response.ok) throw err('internal', `PayMongo intent creation failed (${response.status})`, payload)

      const intent = (payload as { data?: { id?: string; attributes?: { client_key?: string } } })?.data
      intentId = intent?.id
      clientKey = intent?.attributes?.client_key
      if (typeof intentId !== 'string' || typeof clientKey !== 'string') throw err('internal', 'Unexpected PayMongo response')
    } catch (e) {
      await releaseClaim(orderRef)
      throw e
    }

    await orderRef.update({ paymentIntentId: intentId, updatedAt: FieldValue.serverTimestamp() })
    return { intentId, clientKey, amount: amountCents }
  }),
)

async function retrieveIntent(intentId: string, secretKey: string): Promise<{ attributes?: { status?: string; last_payment?: string | { id?: string } } } | null> {
  try {
    const response = await fetch(`${PAYMONGO_API_URL}/payment_intents/${intentId}`, {
      headers: { Authorization: `Basic ${btoa(`${secretKey}:`)}` },
    })
    if (!response.ok) return null
    const payload: unknown = await response.json().catch(() => null)
    return (payload as { data?: { attributes?: { status?: string; last_payment?: string | { id?: string } } } })?.data ?? null
  } catch {
    return null
  }
}

async function releaseClaim(orderRef: any): Promise<void> {
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(orderRef)
    if (snap.exists && snap.data()?.paymentStatus === 'processing') {
      tx.update(orderRef, { paymentStatus: 'pending', updatedAt: FieldValue.serverTimestamp() })
    }
  })
}