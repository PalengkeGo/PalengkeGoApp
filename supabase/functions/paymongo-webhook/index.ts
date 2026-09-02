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
import { computeOrderAmountCents, settledRefundCents, verifyWebhookSignature } from '../_shared/logic.ts'

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
      amount?: number
      last_payment_error?: unknown
      refunds?: Array<{ id?: string; amount?: number; status?: string }>
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
    // Defense-in-depth (audit 2026-08-23): the intent amount is set
    // server-side, so a mismatch should be impossible — but the money still
    // moved, so the order is marked paid and the mismatch logged LOUDLY.
    const expectedCents = computeOrderAmountCents(order)
    const eventCents = payment?.attributes?.amount
    if (typeof eventCents === 'number' && eventCents !== expectedCents) {
      console.error(
        `PAYMENT AMOUNT MISMATCH: order ${snap.docs[0].id} expected `
          + `${expectedCents} centavos but PayMongo reported ${eventCents} `
          + `(intent ${paymentIntentId}). Investigate before fulfilling.`,
      )
    }
    update.paymentStatus = 'paid'
    update.paidAt = FieldValue.serverTimestamp()
    update.paymentId = typeof payment?.id === 'string' ? payment.id : null
  } else if (type === 'payment.refunded') {
    if (order.paymentStatus === 'refunded') {
      return // idempotent — PayMongo may redeliver
    }
    // Partial-refund aware (audit 2026-08-23 M5) — mirrors
    // functions/src/payments.ts: keep a running `refundedAmount` and only
    // flip to `refunded` on full settlement; not-computable events fall
    // back to legacy full-refund semantics.
    const totalCents = computeOrderAmountCents(order)
    const alreadyRefunded =
      typeof order.refundedAmount === 'number' && Number.isFinite(order.refundedAmount)
        ? order.refundedAmount
        : 0
    const refunds = payment?.attributes?.refunds
    const settled = settledRefundCents(refunds)
    const newRefunded =
      settled !== null
        ? Math.min(Math.max(settled, alreadyRefunded), totalCents)
        : totalCents
    const refundIds = Array.isArray(refunds)
      ? refunds
          .map((r) => r?.id)
          .filter((id): id is string => typeof id === 'string' && id.length > 0)
      : []

    update.refundId = refundIds.length > 0 ? refundIds[0] : null
    if (refundIds.length > 0) {
      update.refundIds = FieldValue.arrayUnion(...refundIds)
    }
    update.paymentId = typeof payment?.id === 'string' ? payment.id : null

    if (newRefunded >= totalCents) {
      update.paymentStatus = 'refunded'
      update.refundedAt = FieldValue.serverTimestamp()
      update.refundedAmount = totalCents
    } else {
      update.refundedAmount = newRefunded
      if (order.paymentStatus === 'refundPending') {
        update.paymentStatus = 'paid'
      }
    }
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
