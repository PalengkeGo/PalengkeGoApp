import { onCall, onRequest, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { FieldValue, Timestamp, DocumentReference } from 'firebase-admin/firestore';
import { createHmac, randomUUID, timingSafeEqual } from 'crypto';
import { PAYMONGO_API_URL, validateOptionalText, FIELD_LIMITS } from './constants';
import { APP_CHECK_ENFORCED, rateLimit } from './security';
import { stallOwnerUid } from './orders';

const db = admin.firestore();

/**
 * Trusted payment layer (see docs/PAYMENTS_PAYMONGO.md).
 *
 * The app never sees the PayMongo secret key. It asks this function to create
 * a Payment Intent (server-side, secret key + Idempotency-Key), receives the
 * short-lived `client_key` back, and attaches the payment method itself with
 * the PUBLIC key. The outcome arrives here as a verified webhook, which is the
 * only path that flips an order's `paymentStatus`.
 *
 * Env (set via `firebase functions:secrets:set` — never committed):
 *   PAYMONGO_SECRET_KEY      sk_test_… / sk_live_…
 *   PAYMONGO_WEBHOOK_SECRET  endpoint secret shown in the PayMongo dashboard
 */

async function roleOf(uid: string): Promise<string | null> {
  const snap = await db.collection('users').doc(uid).get();
  return snap.exists ? (snap.data()?.role as string | null) : null;
}

/**
 * Rolls a `processing` claim back to `pending` after a failed intent
 * creation, so the customer can retry. Only rewrites when the status is
 * STILL `processing` — a webhook may legitimately have flipped it in the
 * meantime, and that outcome must not be clobbered.
 */
async function releaseClaim(orderRef: DocumentReference): Promise<void> {
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(orderRef);
    if (snap.exists && snap.data()?.paymentStatus === 'processing') {
      tx.update(orderRef, {
        paymentStatus: 'pending',
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
  });
}

/**
 * Rolls a `refundPending` claim back to `paid` after a failed PayMongo refund
 * creation. Only rewrites when the status is STILL `refundPending` — a
 * webhook settlement in the meantime must not be clobbered.
 */
async function releaseRefundClaim(
  orderRef: DocumentReference,
): Promise<void> {
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(orderRef);
    if (snap.exists && snap.data()?.paymentStatus === 'refundPending') {
      tx.update(orderRef, {
        paymentStatus: 'paid',
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
  });
}

/** How long a `processing` claim may sit before it is considered abandoned. */
export const CLAIM_STALE_MS = 10 * 60 * 1000;

export type ClaimDecision = 'fresh-processing' | 'reclaim' | 'inspect-intent';

/**
 * Pure decision for a `processing` paymentStatus encountered while claiming:
 *  - fresh-processing: an intent is in flight — reject the caller.
 *  - reclaim: the claim is stale AND no intent was ever stamped (crash
 *    between claim and stamp) — safe to re-claim and create a new intent.
 *  - inspect-intent: the claim is stale but an intent exists — the caller
 *    must retrieve the intent from PayMongo before deciding (it may have
 *    silently succeeded, been canceled, or still be open at the e-wallet).
 */
export function claimDecision(
  paymentIntentId: unknown,
  updatedAtMs: number | undefined,
  nowMs: number,
  staleAfterMs: number = CLAIM_STALE_MS,
): ClaimDecision {
  const stale = updatedAtMs === undefined || nowMs - updatedAtMs >= staleAfterMs;
  if (!stale) {
    return 'fresh-processing';
  }
  return typeof paymentIntentId === 'string' && paymentIntentId.length > 0
      ? 'inspect-intent'
      : 'reclaim';
}

interface RetrievedIntent {
  attributes?: {
    status?: string;
    last_payment?: string | { id?: string };
  };
}

/** GETs a Payment Intent from PayMongo (secret key) — null on any failure. */
async function retrieveIntent(
  intentId: string,
  secretKey: string,
): Promise<RetrievedIntent | null> {
  try {
    const response = await fetch(
      `${PAYMONGO_API_URL}/payment_intents/${intentId}`,
      {
        headers: {
          Authorization: `Basic ${Buffer.from(`${secretKey}:`).toString('base64')}`,
        },
      },
    );
    if (!response.ok) {
      return null;
    }
    const payload: unknown = await response.json().catch(() => null);
    return (payload as { data?: RetrievedIntent })?.data ?? null;
  } catch {
    return null;
  }
}

// ── Pure helpers (exported for unit tests) ───────────────────────────────────

/**
 * Verifies the `Paymongo-Signature` header against the RAW request body.
 * MUST run before parsing the body or touching the database.
 *
 * PayMongo's documented header format is comma-separated segments
 * (`t=<unix seconds>,te=<test sig>,li=<live sig>`); the signed string is
 * `<t>.<raw body>` HMAC-SHA256'd with the endpoint secret (hex). A bare
 * hex header (older format) is still accepted to avoid breaking endpoints
 * verified against that format.
 *
 * Segmented headers also carry a timestamp, which is checked against a
 * replay window (default 5 minutes) when `nowMs` is supplied.
 */
export function parseSignatureHeader(
  signatureHeader: string,
): { t?: string; te?: string; li?: string } {
  const parts: Record<string, string> = {};
  for (const segment of signatureHeader.split(',')) {
    const eq = segment.indexOf('=');
    if (eq > 0) {
      const key = segment.slice(0, eq).trim();
      const value = segment.slice(eq + 1).trim();
      if (key) parts[key] = value;
    }
  }
  return { t: parts.t, te: parts.te, li: parts.li };
}

export const WEBHOOK_MAX_AGE_MS = 5 * 60 * 1000;

function constantTimeHexEqual(expected: string, provided: string): boolean {
  const a = Buffer.from(expected);
  const b = Buffer.from(provided);
  return a.length === b.length && timingSafeEqual(a, b);
}

export function verifyWebhookSignature(
  rawBody: Buffer | string,
  secret: string,
  signatureHeader: string,
  nowMs?: number,
  maxAgeMs: number = WEBHOOK_MAX_AGE_MS,
): boolean {
  if (!signatureHeader) {
    return false;
  }
  const { t, te, li } = parseSignatureHeader(signatureHeader);

  if (t !== undefined || te !== undefined || li !== undefined) {
    if (t === undefined) {
      return false;
    }
    const signed = `${t}.${rawBody.toString()}`;
    const expected = createHmac('sha256', secret).update(signed).digest('hex');
    const matches =
      (te !== undefined && te !== '' && constantTimeHexEqual(expected, te)) ||
      (li !== undefined && li !== '' && constantTimeHexEqual(expected, li));
    if (!matches) {
      return false;
    }
    if (nowMs !== undefined) {
      const age = nowMs - Number(t) * 1000;
      // NaN (malformed t) or an out-of-window timestamp fails closed.
      if (!Number.isFinite(age) || age < -maxAgeMs || age > maxAgeMs) {
        return false;
      }
    }
    return true;
  }

  // Legacy bare-hex header: HMAC of the raw body alone.
  const expected = createHmac('sha256', secret).update(rawBody).digest('hex');
  return constantTimeHexEqual(expected, signatureHeader);
}

export type PayMongoMethod = 'card' | 'gcash' | 'maya';

/**
 * App payment-method ids → PayMongo source names. The app's id is `paymaya`
 * today; PayMongo's current source is `maya` — map, don't pass through.
 */
const METHOD_ALIASES: Record<string, PayMongoMethod> = {
  card: 'card',
  gcash: 'gcash',
  maya: 'maya',
  paymaya: 'maya',
};

export function normalizePaymentMethod(method: unknown): PayMongoMethod | null {
  if (typeof method !== 'string') {
    return null;
  }
  return METHOD_ALIASES[method.toLowerCase()] ?? null;
}

/**
 * Server-side order total in centavos — NEVER trust the client's amount.
 * Mirrors the revenue math in reports.ts / sales.ts so every surface agrees.
 */
export function computeOrderAmountCents(order: Record<string, unknown>): number {
  const itemsTotal = Array.isArray(order.items)
    ? (order.items as Array<{ unitPrice?: number; quantity?: number }>).reduce(
        (sum, i) => sum + (i.unitPrice ?? 0) * (i.quantity ?? 0),
        0,
      )
    : 0;
  const total =
    itemsTotal +
    (typeof order.deliveryFee === 'number' ? order.deliveryFee : 0) +
    (typeof order.serviceFee === 'number' ? order.serviceFee : 0) +
    (typeof order.priorityFee === 'number' ? order.priorityFee : 0);
  return Math.round(total * 100);
}

// ── Callable: create the Payment Intent ──────────────────────────────────────

export const createPaymentIntent = onCall(
  { secrets: ['PAYMONGO_SECRET_KEY'], enforceAppCheck: APP_CHECK_ENFORCED, timeoutSeconds: 30 },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Sign in required');
    }
    const role = await roleOf(uid);
    if (role !== 'customer') {
      throw new HttpsError('permission-denied', 'Only customers can pay');
    }
    await rateLimit(uid, 'createPaymentIntent', 10);

    const data = request.data ?? {};
    const orderId: unknown = data.orderId;
    const method = normalizePaymentMethod(data.paymentMethod);
    if (typeof orderId !== 'string' || orderId.length === 0) {
      throw new HttpsError('invalid-argument', 'Missing orderId');
    }
    if (!method) {
      throw new HttpsError(
        'invalid-argument',
        'paymentMethod must be one of: card, gcash, maya',
      );
    }

    const secretKey = process.env.PAYMONGO_SECRET_KEY;
    if (!secretKey) {
      throw new HttpsError(
        'failed-precondition',
        'PayMongo is not configured on the backend',
      );
    }

    const orderRef = db.collection('orders').doc(orderId);

    // Atomically CLAIM the order before talking to PayMongo: the guard + the
    // `processing` stamp happen in one transaction, so two concurrent calls
    // cannot both pass the check and create two Payment Intents. A stale
    // claim (function died mid-flight, or the customer abandoned the e-wallet
    // approval) is recovered below instead of rejecting retries forever.
    // Object wrapper: the decision is assigned inside the transaction
    // closure, which TS control-flow analysis cannot see through.
    const claim: { outcome: 'claimed' | ClaimDecision } = { outcome: 'claimed' };
    const order: Record<string, unknown> = await db.runTransaction(async (tx) => {
      const orderSnap = await tx.get(orderRef);
      if (!orderSnap.exists) {
        throw new HttpsError('not-found', 'Order not found');
      }
      const order = orderSnap.data()!;

      if (order.customerUid !== uid) {
        throw new HttpsError('permission-denied', 'Not your order');
      }
      if (order.status !== 'pending') {
        throw new HttpsError(
          'failed-precondition',
          'Only pending orders can be paid',
        );
      }
      if (order.paymentStatus === 'paid') {
        throw new HttpsError('already-exists', 'Order is already paid');
      }
      if (order.paymentStatus === 'processing') {
        const updatedAtMs =
          order.updatedAt instanceof Timestamp
            ? order.updatedAt.toMillis()
            : undefined;
        const decision = claimDecision(
          order.paymentIntentId,
          updatedAtMs,
          Date.now(),
        );
        if (decision === 'fresh-processing') {
          throw new HttpsError(
            'failed-precondition',
            'A payment is already in progress for this order',
          );
        }
        claim.outcome = decision;
      }

      tx.update(orderRef, {
        paymentStatus: 'processing',
        updatedAt: FieldValue.serverTimestamp(),
      });
      return order;
    });

    if (claim.outcome === 'inspect-intent') {
      // A stale claim with a stamped intent: the intent may have succeeded
      // (webhook lost), been canceled, or still be open at the e-wallet.
      // Retrieving it is the only safe way to decide — re-claiming blindly
      // could orphan a still-payable intent (paid money, no order).
      const staleIntentId = order.paymentIntentId as string;
      const intent = await retrieveIntent(staleIntentId, secretKey);
      const status = intent?.attributes?.status;
      if (status === 'succeeded') {
        // Self-heal the lost webhook outcome, then tell the caller it's paid.
        const lastPayment = intent?.attributes?.last_payment;
        const paymentId = typeof lastPayment === 'string'
          ? lastPayment
          : (typeof lastPayment === 'object' && lastPayment !== null
              ? lastPayment.id ?? null
              : null);
        await orderRef.update({
          paymentStatus: 'paid',
          paidAt: FieldValue.serverTimestamp(),
          paymentId,
          updatedAt: FieldValue.serverTimestamp(),
        });
        throw new HttpsError('already-exists', 'Order is already paid');
      }
      if (status !== 'canceled') {
        // Still open or genuinely processing at PayMongo — do not create a
        // second intent; the vendor can cancel the order if the customer
        // abandoned it.
        throw new HttpsError(
          'failed-precondition',
          'A payment is still pending for this order — complete or cancel it '
            + 'in your e-wallet app, or contact the stall',
        );
      }
      // canceled intent → safe to fall through and create a fresh one.
    }

    // Server-side amount + PayMongo's documented limits (PHP 1.00 minimum;
    // e-wallets PHP 100,000 max; cards under PHP 10,000,000).
    const amountCents = computeOrderAmountCents(order);
    if (amountCents < 100) {
      await releaseClaim(orderRef);
      throw new HttpsError(
        'invalid-argument',
        'Order total is below the PHP 1.00 minimum',
      );
    }
    if (method !== 'card' && amountCents > 10_000_000) {
      await releaseClaim(orderRef);
      throw new HttpsError(
        'invalid-argument',
        'E-wallet transactions are capped at PHP 100,000',
      );
    }
    if (method === 'card' && amountCents >= 1_000_000_000) {
      await releaseClaim(orderRef);
      throw new HttpsError(
        'invalid-argument',
        'Card transactions must be below PHP 10,000,000',
      );
    }

    // Allow the full supported set so a failed payment can be retried with a
    // different method on the SAME intent (payment_method_allowed is fixed at
    // creation time and cannot be changed later).
    let intentId: string | undefined;
    let clientKey: string | undefined;
    try {
      const response = await fetch(`${PAYMONGO_API_URL}/payment_intents`, {
        method: 'POST',
        headers: {
          Authorization: `Basic ${Buffer.from(`${secretKey}:`).toString('base64')}`,
          'Content-Type': 'application/json',
          // Unique per request — protects against double-charges on retries.
          'Idempotency-Key': randomUUID(),
        },
        body: JSON.stringify({
          data: {
            attributes: {
              amount: amountCents,
              currency: 'PHP',
              payment_method_allowed: ['card', 'gcash', 'maya'],
              description: `Order #${orderId}`,
              metadata: { orderId },
            },
          },
        }),
      });

      const payload: unknown = await response.json().catch(() => null);
      if (!response.ok) {
        throw new HttpsError(
          'internal',
          `PayMongo intent creation failed (${response.status})`,
          payload,
        );
      }

      const intent = (payload as { data?: { id?: string; attributes?: { client_key?: string } } })?.data;
      intentId = intent?.id;
      clientKey = intent?.attributes?.client_key;
      if (typeof intentId !== 'string' || typeof clientKey !== 'string') {
        throw new HttpsError('internal', 'Unexpected PayMongo response');
      }
    } catch (err) {
      // Intent creation failed — release the claim so the customer can retry.
      await releaseClaim(orderRef);
      throw err;
    }

    // Stamp the intent id so the webhook can find the order. `paymentStatus`
    // is already `processing` from the claim. The client key is short-lived
    // and only returned to the caller — it is intentionally NOT persisted.
    await orderRef.update({
      paymentIntentId: intentId,
      updatedAt: FieldValue.serverTimestamp(),
    });

    return { intentId, clientKey, amount: amountCents };
  },
);

// ── Webhook: verified outcome → Firestore ────────────────────────────────────

/**
 * Receives `payment.paid` / `payment.failed` from PayMongo.
 *
 * The signature is verified against the RAW body BEFORE parsing. Unverified
 * requests are rejected with 401; verified-but-unprocessable events respond
 * 500 so PayMongo retries. Only this function (admin SDK) may change an
 * order's `paymentStatus` to paid/failed — the Firestore rules block clients.
 */
export const paymongoWebhook = onRequest(
  { secrets: ['PAYMONGO_WEBHOOK_SECRET'] },
  async (req, res) => {
    const secret = process.env.PAYMONGO_WEBHOOK_SECRET;
    const raw = req.rawBody;
    const signature = req.headers['paymongo-signature'];

    if (
      !secret ||
      !raw ||
      typeof signature !== 'string' ||
      !verifyWebhookSignature(raw, secret, signature, Date.now())
    ) {
      res.status(401).send('Invalid signature');
      return;
    }

    let event: {
      data?: {
        attributes?: {
          type?: string;
          data?: {
            id?: string;
            attributes?: {
              payment_intent_id?: string;
              status?: string;
              last_payment_error?: unknown;
            };
          };
        };
      };
    };
    try {
      event = JSON.parse(raw.toString('utf8'));
    } catch {
      res.status(400).send('Invalid JSON body');
      return;
    }

    const type = event?.data?.attributes?.type;
    const paymentIntentId = event?.data?.attributes?.data?.attributes?.payment_intent_id;
    const payment = event?.data?.attributes?.data;

    if (typeof paymentIntentId !== 'string') {
      // Not a payment-outcome event we act on — ack so PayMongo stops retrying.
      res.status(200).json({ received: true });
      return;
    }

    try {
      if (
        type === 'payment.paid' ||
        type === 'payment.failed' ||
        type === 'payment.refunded'
      ) {
        await applyPaymentOutcome(type, paymentIntentId, payment);
      }
      res.status(200).json({ received: true });
    } catch (err) {
      console.error('Webhook processing failed:', err);
      res.status(500).send('Processing failed'); // PayMongo will retry
    }
  },
);

async function applyPaymentOutcome(
  type: 'payment.paid' | 'payment.failed' | 'payment.refunded',
  paymentIntentId: string,
  payment: {
    id?: string;
    attributes?: {
      status?: string;
      last_payment_error?: unknown;
      refunds?: Array<{ id?: string }>;
    };
  } | undefined,
): Promise<void> {
  const snap = await db
    .collection('orders')
    .where('paymentIntentId', '==', paymentIntentId)
    .limit(1)
    .get();

  if (snap.empty) {
    console.warn(`No order found for intent ${paymentIntentId}`);
    return;
  }

  const orderRef = snap.docs[0].ref;
  const order = snap.docs[0].data();

  const update: Record<string, unknown> = {
    updatedAt: FieldValue.serverTimestamp(),
  };

  if (type === 'payment.paid') {
    if (order.paymentStatus === 'paid') {
      return; // idempotent — PayMongo may redeliver
    }
    update.paymentStatus = 'paid';
    update.paidAt = FieldValue.serverTimestamp();
    update.paymentId = typeof payment?.id === 'string' ? payment.id : null;
  } else if (type === 'payment.refunded') {
    if (order.paymentStatus === 'refunded') {
      return; // idempotent — PayMongo may redeliver
    }
    update.paymentStatus = 'refunded';
    update.refundedAt = FieldValue.serverTimestamp();
    const refunds = payment?.attributes?.refunds;
    update.refundId =
      Array.isArray(refunds) && refunds.length > 0
        ? refunds[0].id ?? null
        : null;
    update.paymentId = typeof payment?.id === 'string' ? payment.id : null;
  } else {
    // A duplicate/delayed `payment.failed` must never downgrade an order the
    // webhook already settled (PayMongo may redeliver out of order).
    if (
      order.paymentStatus === 'paid' ||
      order.paymentStatus === 'refunded' ||
      order.paymentStatus === 'refundPending'
    ) {
      return;
    }
    update.paymentStatus = 'failed';
    // PayMongo returns the intent to awaiting_payment_method on failure, so
    // the customer can retry with another method; keep the last intent id for
    // audit and record why it failed.
    update.lastPaymentError =
      payment?.attributes?.last_payment_error ??
      payment?.attributes?.status ??
      null;
  }

  await orderRef.update(update);
}

// ── Callable: refund a paid order ────────────────────────────────────────────

/**
 * Refunds a PayMongo-paid order. Only the stall owner or an admin may refund.
 * The amount is recomputed server-side (or a validated partial amount is
 * accepted); the refund is created via the PayMongo API with an idempotency
 * key, and the order is marked `refunded` only after PayMongo confirms.
 *
 * The `payment.refunded` webhook also flips the order, so this endpoint and
 * the webhook are mutually idempotent.
 */
export const createRefund = onCall(
  {
    secrets: ['PAYMONGO_SECRET_KEY'],
    enforceAppCheck: APP_CHECK_ENFORCED,
    timeoutSeconds: 30,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Sign in required');
    }
    await rateLimit(uid, 'createRefund', 5);

    const role = await roleOf(uid);
    const data = request.data ?? {};
    const orderId: unknown = data.orderId;
    if (typeof orderId !== 'string' || orderId.length === 0) {
      throw new HttpsError('invalid-argument', 'Missing orderId');
    }
    const reasonError = validateOptionalText(
      data.reason,
      FIELD_LIMITS.refundReason,
      'reason',
    );
    if (reasonError) {
      throw new HttpsError('invalid-argument', reasonError);
    }

    const secretKey = process.env.PAYMONGO_SECRET_KEY;
    if (!secretKey) {
      throw new HttpsError(
        'failed-precondition',
        'PayMongo is not configured on the backend',
      );
    }

    const orderRef = db.collection('orders').doc(orderId);

    // Authorization first (owner/admin), then atomically CLAIM the refund:
    // `paid → refundPending` in one transaction, so two near-simultaneous
    // refund calls (e.g. owner + admin) cannot both see `paid` and create
    // two PayMongo refunds. A failed PayMongo call releases the claim.
    const orderSnap0 = await orderRef.get();
    if (!orderSnap0.exists) {
      throw new HttpsError('not-found', 'Order not found');
    }
    const ownerUid = await stallOwnerUid(orderSnap0.data()!.stallId);
    if (role !== 'admin' && ownerUid !== uid) {
      throw new HttpsError(
        'permission-denied',
        'Only the stall owner or an admin can refund this order',
      );
    }

    const order: Record<string, unknown> = await db.runTransaction(async (tx) => {
      const orderSnap = await tx.get(orderRef);
      if (!orderSnap.exists) {
        throw new HttpsError('not-found', 'Order not found');
      }
      const orderData = orderSnap.data()!;
      if (orderData.paymentStatus !== 'paid') {
        throw new HttpsError(
          'failed-precondition',
          'Only paid orders can be refunded',
        );
      }
      tx.update(orderRef, {
        paymentStatus: 'refundPending',
        updatedAt: FieldValue.serverTimestamp(),
      });
      return orderData;
    });

    const paymentId: unknown = order.paymentId;
    if (typeof paymentId !== 'string') {
      await releaseRefundClaim(orderRef);
      throw new HttpsError(
        'failed-precondition',
        'This order has no PayMongo payment record',
      );
    }

    // Full amount by default; a partial amount is accepted but capped at the
    // order total and never below the PHP 1.00 minimum.
    const totalCents = computeOrderAmountCents(order);
    const requested =
      typeof data.amount === 'number' && Number.isFinite(data.amount)
        ? Math.round(data.amount * 100)
        : totalCents;
    if (requested < 100) {
      await releaseRefundClaim(orderRef);
      throw new HttpsError(
        'invalid-argument',
        'Refund amount is below the PHP 1.00 minimum',
      );
    }
    if (requested > totalCents) {
      await releaseRefundClaim(orderRef);
      throw new HttpsError(
        'invalid-argument',
        'Refund amount exceeds the order total',
      );
    }

    let response: Response;
    try {
      response = await fetch(`${PAYMONGO_API_URL}/refunds`, {
        method: 'POST',
        headers: {
          Authorization: `Basic ${Buffer.from(`${secretKey}:`).toString('base64')}`,
          'Content-Type': 'application/json',
          'Idempotency-Key': randomUUID(),
        },
        body: JSON.stringify({
          data: {
            attributes: {
              payment_id: paymentId,
              amount: requested,
              reason: typeof data.reason === 'string' ? data.reason : 'Refund requested',
              metadata: { orderId },
            },
          },
        }),
      });
    } catch (err) {
      await releaseRefundClaim(orderRef);
      throw err;
    }

    const payload: unknown = await response.json().catch(() => null);
    if (!response.ok) {
      await releaseRefundClaim(orderRef);
      throw new HttpsError(
        'internal',
        `PayMongo refund creation failed (${response.status})`,
        payload,
      );
    }

    const refund = (payload as {
      data?: { id?: string; attributes?: { status?: string } };
    })?.data;
    const refundId: string | undefined = refund?.id;
    if (typeof refundId !== 'string') {
      await releaseRefundClaim(orderRef);
      throw new HttpsError('internal', 'Unexpected PayMongo refund response');
    }

    // PayMongo refunds can settle asynchronously (status `pending` before the
    // funds move). Only a confirmed refund flips the order to `refunded`; a
    // pending one stays `refundPending` (the claim above) and the
    // `payment.refunded` webhook performs the authoritative flip when the
    // money has moved.
    const refundStatus = refund?.attributes?.status;
    if (refundStatus === 'pending' || refundStatus === 'processing') {
      await orderRef.update({
        refundId,
        updatedAt: FieldValue.serverTimestamp(),
      });
      return { refundId, amount: requested, refundStatus: 'pending' };
    }

    await orderRef.update({
      paymentStatus: 'refunded',
      refundId,
      refundedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    await orderRef.collection('statusHistory').add({
      orderId,
      previousStatus: order.status,
      newStatus: order.status,
      changedBy: uid,
      changedAt: FieldValue.serverTimestamp(),
      remarks: `Refund issued (${refundId})`,
    });

    return { refundId, amount: requested };
  },
);
