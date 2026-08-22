# Payments: PayMongo Flow & Security (Firebase + Supabase)

Reference for wiring real payments into PalengkeGo. The stack is:

- **Firebase** — Auth + Firestore (users, orders). Orders already live here via
  `FirebaseOrderRepository`.
- **Supabase** — recipe/content store today; can host the payment endpoint as an
  Edge Function if preferred.
- **PayMongo** — payment processing (cards, GCash, Maya). PayMongo is a PCI
  Service Provider Level 1; this app must never touch raw card data or hold a
  secret key.

Facts below are from the current PayMongo docs (docs.paymongo.com, "Payment
Acceptance" and "Developer Tools → Best Practices") as of Aug 2026.

---

## 1. Who holds what

| Secret / key | Where it lives | Never in |
|---|---|---|
| `PAYMONGO_SECRET_KEY` (`sk_…`) | Backend env only (Firebase Function / Supabase Edge Function) | App code, binaries, repos |
| `PAYMONGO_PUBLIC_KEY` (`pk_…`) | Client via `--dart-define` (already in `AppConfig.paymongoPublicKey`) | — |
| Webhook secret (endpoint secret) | Backend env only | App code |
| `PAYMONGO_BACKEND_URL` | Client via `--dart-define` (already in `AppConfig.paymongoBackendUrl`), points at your backend | — |
| Card PAN / CVV | **Never** — collected client-side, tokenized by PayMongo | Your backend (avoiding PCI-DSS scope) |

Rule of thumb: the app talks only to **your** backend; your backend talks to
PayMongo. The client never calls `api.paymongo.com` with the secret key.

---

## 2. End-to-end flow (Payment Intent)

PayMongo's model is the **Payment Intent** — one server-side record per
checkout. Amounts are always in **centavos** (PHP 100.00 → `10000`).

```
Customer          Flutter app               Your backend            PayMongo
   │                   │                         │                     │
   │  Place order      │                         │                     │
   ├──────────────────►│  CheckoutController      │                     │
   │                   │  .placeOrder()           │                     │
   │                   │  POST /create-payment    │                     │
   │                   ├─────────────────────────►│  POST /v1/payment_  │
   │                   │   {orderId, amount,      │  intents            │
   │                   │    methods:[card,gcash,  │  (secret key,       │
   │                   │    maya]}                │   Idempotency-Key)  │
   │                   │                          ├────────────────────►│
   │                   │  {intentId, client_key}  │◄────────────────────┤
   │                   │◄─────────────────────────┤                     │
   │                   │  create+attach payment   │                     │
   │                   │  method (public key +    │                     │
   │                   │  client_key)             │                     │
   │                   ├──────────────────────────┼────────────────────►│
   │                   │  next_action: redirect/  │                     │
   │                   │  3DS/QR                  │                     │
   │  e-wallet app /   │◄─────────────────────────┼─────────────────────┤
   │  bank page        │                          │                     │
   │◄──────────────────┤                          │                     │
   │  authorize        │                          │                     │
   ├──────────────────►│                          │                     │
   │                   │                          │   payment.paid /    │
   │                   │  webhook (verify HMAC)   │   payment.failed    │
   │                   │◄─────────────────────────┼─────────────────────┤
   │                   │  update Firestore order  │                     │
   │                   │  paymentStatus           │                     │
   │  order paid ✓     │                          │                     │
   │◄──────────────────┤                          │                     │
```

### The five steps

1. **Create the Payment Intent (server-side, secret key).**
   ```bash
   POST https://api.paymongo.com/v1/payment_intents
   Authorization: Basic <base64(sk_test_...)>
   Idempotency-Key: <unique-per-request>
   {
     "data": { "attributes": {
       "amount": 10000,
       "currency": "PHP",
       "payment_method_allowed": ["card", "gcash", "maya"],
       "description": "Order #88293"
     } }
   }
   ```
   Response gives you `id` and a short-lived **`client_key`** — pass the key to
   the app, keep the intent id on the server.

2. **Create the Payment Method (client-side, public key + client_key).**
   The app collects card details (PayMongo's fields / your own tokenization) or
   selects an e-wallet, and calls Create Payment Method with `pk_…`. Card data
   never touches your backend.

3. **Attach the method to the intent (client-side).** Returns a `next_action`:
   a redirect URL (GCash/Maya), a 3DS authorization URL (cards), or a QR.
   Direct the customer there.

4. **Customer completes the action.** Then PayMongo processes:
   `awaiting_payment_method → awaiting_next_action → processing → succeeded`.

5. **Outcome via webhook (server-side).** PayMongo sends `payment.paid` /
   `payment.failed` / `payment.refunded`. Verify the signature, update the
   order in Firestore, then tell the app (it watches its order doc). Polling
   the intent is a fallback, but webhooks are the production-reliable path.

### Facts to encode

- **No explicit `failed` status.** A failed payment returns the intent to
  `awaiting_payment_method` with `last_payment_error`; the customer can retry
  with another method.
- **E-wallet action windows:** Maya **30 min**, GCash **4 h** (GrabPay 15 min,
  ShopeePay 20 min). Expiry returns the intent to `awaiting_payment_method`.
- **E-wallet per-transaction max: PHP 100,000**; min PHP 1.00. Cards: min
  PHP 1.00, max < PHP 10,000,000.
- PayMongo currently lists the Maya source as **`maya`** (formerly `paymaya`).
  The app's payment-method id is `paymaya` today; map `paymaya → maya` when
  calling the API, and render the Maya mark accordingly if you rebrand.

---

## 3. Webhook signature verification

Every webhook carries a **`Paymongo-Signature`** header:

```
HMAC-SHA256(raw request body, endpoint webhook secret)  →  hex
```

Verify **before** parsing anything, using the **raw** body, with a
**timing-safe** compare. PayMongo requires your webhook URL to be HTTPS.

```typescript
// functions/src/payments.ts (Firebase Functions) — Deno/Supabase equivalent below
import { createHmac, timingSafeEqual } from "crypto";

export function verifyWebhookSignature(
  rawBody: Buffer | string,
  secret: string,
  signatureHeader: string,
): boolean {
  const expected = createHmac("sha256", secret)
    .update(rawBody)
    .digest("hex");
  const a = Buffer.from(expected);
  const b = Buffer.from(signatureHeader);
  return a.length === b.length && timingSafeEqual(a, b);
}
```

```typescript
// Handler sketch
export const paymongoWebhook = onRequest({ secrets: ["PAYMONGO_WEBHOOK_SECRET"] },
  (req, res) => {
    const raw = req.rawBody; // must be the unparsed bytes
    if (!verifyWebhookSignature(raw, process.env.PAYMONGO_WEBHOOK_SECRET!,
        req.headers["paymongo-signature"] ?? "")) {
      return res.status(401).end(); // reject: not from PayMongo
    }
    const event = JSON.parse(raw.toString("utf8"));
    // event.data.attributes.type === "payment.paid" | "payment.failed"
    // → update Firestore orders/{orderId}.paymentStatus, then 200.
  });
```

- **Verify first** — before body parsing, before DB access.
- **Raw body** — any middleware that reformats the body breaks the signature.
- **Timing-safe compare** — never plain `===` on signatures.
- **Rotate immediately** if a webhook secret leaks (Dashboard → Developers →
  Webhooks).

Supabase Edge Functions (Deno) version uses `crypto.subtle` with the same
scheme; the secret lives in the function's `--secret` env.

---

## 4. Security checklist (non-negotiable)

- [ ] **Secret key never in the app.** `sk_…` exists only in backend env. The
      repo's CI already fails on `sk_live_` / `sk_test_` in source — keep it
      that way.
- [ ] **No raw card data to your backend.** Client-side tokenization only —
      this is what keeps PalengkeGo out of PCI-DSS scope.
- [ ] **Idempotency-Key on every POST** that creates/changes money records
      (create intent, capture, refund). Key per request, scoped to your secret
      key + method. Protects against double-charges on retries.
- [ ] **Verify webhooks** as in §3. Never trust an unverified
      `payment.paid`.
- [ ] **Amounts validated server-side.** Never trust the client's amount;
      recompute the order total on the backend before creating the intent.
- [ ] **HTTPS everywhere.** PayMongo rejects plaintext; your webhook endpoint
      must be HTTPS.
- [ ] **Separate test/live keys.** `sk_test_…` in dev, `sk_live_…` only in
      production. App `AppConfig.validate()` already refuses production without
      a real `pk_…`.
- [ ] **AuthN/AuthZ on your backend endpoint.** The app sends a Firebase ID
      token / App Check token with `POST /create-payment`; the backend verifies
      it and attaches `customerUid` to the intent description or metadata.
- [ ] **Firestore RLS + Supabase RLS.** Orders remain customer-scoped; the
      webhook path updates via the backend (admin SDK), never via client RLS.
- [ ] **3DS on cards.** PayMongo handles 3DS 2.0 redirects automatically when
      required — do not bypass it.

---

## 5. Mapping to this codebase (current state + gaps)

| Piece | Today | What to change |
|---|---|---|
| `PayMongoService` (`core/infrastructure/paymongo_service.dart`) | Placeholder `createPaymentLink`, URL now from `PAYMONGO_BACKEND_URL` dart-define; **zero callers** | Rewrite toward the Intent flow: `createIntent(orderId, amount, methods)` calling your backend |
| `paymongoServiceProvider` | Exists, wired to `AppConfig.paymongoBackendUrl` | Used by the checkout flow once wired |
| `CheckoutController.placeOrder()` | Creates orders with `paymentStatus: pending` | Split flow: order created in `pending` → for gcash/paymaya/card, trigger payment intent; only mark `paid` on webhook |
| `PaymentStatus` (`orders/domain/payment_status.dart`) | `pending / processing / paid / failed / refunded` | — (lifecycle complete) |
| `OrderPolicy` | Order status state machine | Keep `paid` gating (`canTransitionTo`) aligned with webhook updates |
| `functions/` | `payments.ts`: `createPaymentIntent` + `paymongoWebhook` + `createRefund` | Wire the app's checkout to `createPaymentIntent` (last mile) |
| Supabase | Recipes only | Optional: host the same endpoint as an Edge Function instead of Firebase Functions |
| Payment UI (`payment_methods_screen.dart`) | GCash + PayMaya (brand icons) + Card, mocked linking | Replace mock linking with real redirect to PayMongo `next_action` URL |

### Order lifecycle with payments (target)

1. `placeOrders` → trusted `placeOrder` callable creates the Firestore order
   with `paymentStatus: pending` and the chosen `paymentMethod`.
2. gcash/paymaya/card → backend creates intent → app redirects (e-wallet app /
   3DS).
3. Webhook `payment.paid` (verified) → backend sets `paymentStatus: paid`
   (idempotent).
4. App sees the order update (Firestore snapshot) → proceeds to confirmation /
   vendor fulfilment. `OrderPolicy.canTransitionTo` unchanged — it already
   guards status transitions; payment just becomes the gate for paid-only
   transitions.

---

## 6. Environment configuration

```bash
# Flutter (app) — public, safe
flutter run --dart-define=PAYMONGO_PUBLIC_KEY=pk_test_xxx \
            --dart-define=PAYMONGO_BACKEND_URL=https://asia-southeast1-<project>.cloudfunctions.net/createPayment

# Backend (Firebase Functions) — secret, env only
firebase functions:secrets:set PAYMONGO_SECRET_KEY
firebase functions:secrets:set PAYMONGO_WEBHOOK_SECRET
```

Test mode: PayMongo dashboard → Test Mode. Test card `4242 4242 4242 4242`
works for card flows; e-wallets in test mode return mock redirects.

---

## 7. What is implemented (Aug 2026)

### Trusted backend (functions/)

All order mutations now run through Cloud Functions — the app **never writes
prices, stock, or statusHistory directly**:

| Callable | Endpoint | Does |
|---|---|---|
| `placeOrder` | `functions/src/orders.ts` | Recomputes prices + fees server-side, deducts stock transactionally, stamps `paymentMethod`, writes the immutable `statusHistory` entry with the real acting uid |
| `updateOrderStatus` | `functions/src/orders.ts` | State machine + ownership checks; allows same-status re-records (estimated ready time); marks **cash** orders paid at completion only |
| `cancelOrder` | `functions/src/orders.ts` | Server-side 5-minute window check (the client clock can't be faked) |
| `addReview` | `functions/src/reviews.ts` | One review per order enforced by a **deterministic doc id** (`ratings/{orderId}_{uid}`) created transactionally — no check-then-write race; the stall aggregate is recomputed in the same transaction |
| `createPaymentIntent` | `functions/src/payments.ts` | Server-side amount (centavos), PayMongo limits, `Idempotency-Key`, returns the short-lived `client_key` |
| `createRefund` | `functions/src/payments.ts` | Stall owner / admin only; full or partial refund capped at the order total; marks the order `refunded` only after PayMongo confirms |
| `paymongoWebhook` | `functions/src/payments.ts` | Verifies `Paymongo-Signature` (HMAC-SHA256, constant-time) against the RAW body; handles `payment.paid` / `payment.failed` / `payment.refunded` idempotently |

`paymentStatus` states: `pending → processing → paid | failed | refunded`.
Cash orders (`cod` / `cop`) are marked `paid` by the vendor at completion;
**online methods (`gcash`/`paymaya`/`card`) can only become `paid` via the
verified webhook** — the Firestore rules block any client write of
`paymentStatus` for them.

### Flutter (app) — wired

- `FirebaseOrderRepository` calls the `placeOrder` / `updateOrderStatus` /
  `cancelOrder` callables; error codes map to the typed `OrderFailure` the UI
  already shows.
- `FirebaseVendorRepository.addReview` calls the `addReview` callable (the
  client-side aggregate write was removed).
- `MarketOrder` now carries `paymentMethod`; the checkout passes the method
  selected on the Payment Methods screen.
- `PaymentStatus.refunded` added.

### Security hardening shipped with it

- **App Check**: every callable is declared with
  `enforceAppCheck: APP_CHECK_ENFORCED` (read from the `APP_CHECK_ENFORCED`
  env var at cold start). Enable it only after the Firebase console has
  **Play Integrity** (Android) and **App Attest** (iOS) configured — the app
  activates `firebase_app_check` at startup (debug providers in dev, Play
  Integrity / App Attest in release):

  ```bash
  firebase functions:config:set appcheck.enforced=true
  ```

- **Rate limiting**: per-user, per-action sliding window backed by Firestore
  (`rateLimits/{action}_{uid}`, 60 s window) — `placeOrder` 10/min,
  `addReview` 10/min, `createPaymentIntent` 10/min, `createRefund` 5/min,
  order-status changes 60/min.
- **Length caps** on every free-text field (`customerName` 100,
  `deliveryAddress` 200, `notes`/`reviewComment` 500, `remarks` 300,
  `refundReason` 200), enforced both in the functions and in the Firestore
  rules.
- **Rules**: `statusHistory` is now write-only-by-functions (`allow create:
  if false`) — the `changedBy: 'system'` forgery vector is gone; vendor
  `paymentStatus` writes are gated to COD completion; orders/ratings enforce
  payment-method and length constraints on create.

### Enabling (one-time)

```bash
firebase functions:secrets:set PAYMONGO_SECRET_KEY
firebase functions:secrets:set PAYMONGO_WEBHOOK_SECRET
firebase deploy --only functions
# after console App Check providers are configured:
firebase functions:config:set appcheck.enforced=true
firebase deploy --only functions
```

---

## 8. Reference

- PayMongo docs — Payment Acceptance (Payment Intent lifecycle, key concepts):
  https://docs.paymongo.com/docs/payment-acceptance-key-concepts
- PayMongo docs — Webhooks setup & `Paymongo-Signature`:
  https://docs.paymongo.com/docs/developer-tools-webhook-setup-management
- PayMongo docs — Best Practices (keys, idempotency, signature verification):
  https://docs.paymongo.com/docs/developer-tools-best-practices-1
