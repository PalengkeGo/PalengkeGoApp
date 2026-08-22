/**
 * PayMongo webhook (ported from functions/src/payments.ts paymongoWebhook).
 *
 * Receives `payment.paid` / `payment.failed` / `payment.refunded`. The
 * signature is verified against the RAW body BEFORE parsing (Web Crypto,
 * constant-time). Unverified requests are rejected with 401; verified-but-
 * unprocessable events respond 500 so PayMongo retries. Only this function
 * (admin SDK) may change an order's `paymentStatus` to paid/failed — the
 * Firestore rules block clients.
 *
 * NOT ported (YAGNI — the app does not call them yet): createPaymentIntent,
 * createRefund, getSalesReport. They stay in functions/src until the payment
 * flow ships. Secret: supabase secret set PAYMONGO_WEBHOOK_SECRET=...
 */

import { db, err, FieldValue, handle } from '../_shared/backend.ts'
import { verifyWebhookSignature } from '../_shared/logic.ts'

Deno.serve((req: Request) =>
  handle(req, async (req) => {
    const secret = Deno.env.get('PAYMONGO_WEBHOOK_SECRET')
    const raw = new Uint8Array(await req.arrayBuffer())
    const signature = req.headers.get('paymongo-signature')

    if (
      !secret ||
      raw.length === 0 ||
      !signature ||
      !(await verifyWebhookSignature(raw, secret, signature, Date.now()))
    ) {
      throw err('unauthorized', 'Invalid signature')
    }

    let event: any
    try {
      event = JSON.parse(new TextDecoder().decode(raw))
    } catch {
      throw err('invalid-argument', 'Invalid JSON body')
    }

    const type = event?.data?.attributes?.type
    const paymentIntentId = event?.data?.attributes?.data?.attributes?.payment_intent_id
    const payment = event?.data?.attributes?.data

    if (typeof paymentIntentId !== 'string') {
      // Not a payment-outcome event we act on — ack so PayMongo stops retrying.
      return { received: true }
    }

    await applyPaymentOutcome(type, paymentIntentId, payment)

    return { received: true }
  }),
)

async function applyPaymentOutcome(
  type: unknown,
  paymentIntentId: string,
  payment: {
    id?: string
    attributes?: {
      status?: string
      last_payment_error?: unknown
      refunds?: Array<{ id?: string }>
    }
  } | undefined,
): Promise<void> {
  if (type !== 'payment.paid' && type !== 'payment.failed' && type !== 'payment.refunded') {
    return // ack non-payment-outcome events
  }

  const snap = await db
    .collection('orders')
    .where('paymentIntentId', '==', paymentIntentId)
    .limit(1)
    .get()

  if (snap.empty) {
    console.warn(`No order found for intent ${paymentIntentId}`)
    return
  }

  const orderRef = snap.docs[0].ref
  const order = snap.docs[0].data()

  const update: Record<string, unknown> = {
    updatedAt: FieldValue.serverTimestamp(),
  }

  if (type === 'payment.paid') {
    if (order.paymentStatus === 'paid') {
      return // idempotent — PayMongo may redeliver
    }
    update.paymentStatus = 'paid'
    update.paidAt = FieldValue.serverTimestamp()
    update.paymentId = typeof payment?.id === 'string' ? payment.id : null
  } else if (type === 'payment.refunded') {
    if (order.paymentStatus === 'refunded') {
      return // idempotent — PayMongo may redeliver
    }
    update.paymentStatus = 'refunded'
    update.refundedAt = FieldValue.serverTimestamp()
    const refunds = payment?.attributes?.refunds
    update.refundId =
      Array.isArray(refunds) && refunds.length > 0 ? refunds[0].id ?? null : null
    update.paymentId = typeof payment?.id === 'string' ? payment.id : null
  } else {
    // A duplicate/delayed `payment.failed` must never downgrade an order the
    // webhook already settled (PayMongo may redeliver out of order).
    if (
      order.paymentStatus === 'paid' ||
      order.paymentStatus === 'refunded' ||
      order.paymentStatus === 'refundPending'
    ) {
      return
    }
    update.paymentStatus = 'failed'
    // PayMongo returns the intent to awaiting_payment_method on failure, so
    // the customer can retry with another method; keep the last intent id for
    // audit and record why it failed.
    update.lastPaymentError =
      payment?.attributes?.last_payment_error ??
      payment?.attributes?.status ??
      null
  }

  await orderRef.update(update)
}
