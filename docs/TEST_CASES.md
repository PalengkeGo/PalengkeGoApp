# PalengkeGo — Master Test Case Catalog & Metrics

Date: 2026-08-22 · Applies to: post-audit remediated codebase (see `docs/audit-2026-08-22.md` §5 statuses)
Companion docs: `docs/QA_PIPELINE.md` (CI mechanics) · `docs/PAYMENTS_PAYMONGO.md` (payment design) · `TEAM_WORKFLOW.md` (git process)

---

## 1. How to read this document

Every test case has:

| Field | Meaning |
|---|---|
| **ID** | `TC-<AREA>-<nn>` — cite this ID in bug reports and PRs |
| **Priority** | P1 = release blocker · P2 = must fix before store submission · P3 = nice-to-have |
| **Type** | `auto` (runs in CI/jest) · `manual` (hands-on device/console) · `api` (curl/Postman against deployed backend) |
| **Preconditions** | Exact state required before starting |
| **Steps** | Numbered, concrete — anyone on the team can execute them |
| **Expected** | The observable pass condition |
| **Metric** | Numeric gate where one exists (timing, count, percentage) |

**Pass rule for the release:** every P1 case green, ≥ 95% of executed P2 cases green with no open defects of severity ≥ Major, all automated suites green (§3).

---

## 2. Test environments & setup

### 2.1 The three run modes

| Mode | Command | Backend | Use for |
|---|---|---|---|
| Mock | `flutter run` | none (in-memory + SharedPreferences) | UI walkthroughs, TC-CART/CHK happy paths |
| Firebase | `flutter run --dart-define=FIREBASE_ENABLED=true` | real Firebase project (or emulators) | all backend-dependent cases |
| Full payment | Firebase mode **+** PayMongo keys + `PAYMONGO_PUBLIC_KEY=pk_test_…` | Firebase + PayMongo test mode | TC-PAY-* |

Backend secrets (never in the app): `firebase functions:secrets:set PAYMONGO_SECRET_KEY` and `…PAYMONGO_WEBHOOK_SECRET`.

### 2.2 Local backend suites (no deploy needed)

```bash
# Firestore rules + functions unit tests (spins up emulators, then jest)
cd functions
export JAVA_HOME="/c/Program Files/Android/Android Studio/jbr"   # Windows: any JDK 17+
npm run test:rules
# → expect: "Test Suites: 5 passed, 5" · "Tests: 81 passed, 81"

# TypeScript compile check
npx tsc --noEmit            # → exit 0, no output

# Long-running emulators for interactive poking (optional)
npm run serve               # firebase emulators:start --project demo-palengkego
```

### 2.3 PayMongo test-mode facts

- Test card (from PayMongo docs / `docs/PAYMENTS_PAYMONGO.md`): **4242 4242 4242 4242**, any future expiry, any CVC.
- E-wallets in test mode return **mock redirect pages** — the redirect lands without a real GCash/Maya app.
- Webhook endpoint (region `asia-southeast1`): `https://asia-southeast1-<PROJECT>.cloudfunctions.net/paymongoWebhook`
- Amount limits enforced server-side: min **PHP 1.00**; e-wallet max **PHP 100,000**; card max < **PHP 10,000,000**.

### 2.4 Webhook simulation (signed, both formats)

The backend accepts PayMongo's segmented header and the legacy bare-hex header. Build a correctly signed request:

```bash
BODY='{"data":{"attributes":{"type":"payment.paid","data":{"id":"pay_test","attributes":{"payment_intent_id":"INTENT_ID_HERE","status":"paid"}}}}}'
SECRET='whsec_your_endpoint_secret'
TS=$(date +%s)
SIG=$(node -e "require('crypto').createHmac('sha256', process.argv[1]).update(process.argv[2]+'.'+process.argv[3]).digest('hex')" "$SECRET" "$TS" "$BODY")

curl -X POST "https://asia-southeast1-<PROJECT>.cloudfunctions.net/paymongoWebhook" \
  -H "Content-Type: application/json" \
  -H "Paymongo-Signature: t=${TS},te=${SIG},li=" \
  -d "$BODY"
# → expect: {"received":true} and the order flips to paymentStatus=paid
```

Replace `payment_intent_id` with the intent id stamped on the Firestore order doc (`orders/{id}.paymentIntentId`).

### 2.5 Seed data expectations

Test users (create in Firebase Console → Authentication, then set `users/{uid}.role` in Firestore):

| Account | role | email verified | used for |
|---|---|---|---|
| `qa-customer@test` | customer | ✅ | all customer flows |
| `qa-customer-unverified@test` | customer | ❌ | TC-AUTH-04 email gate |
| `qa-vendor@test` | vendor | ✅ | order lifecycle, refunds, reports |
| `qa-admin@test` | admin | ✅ | TC-ORD-09 admin path |
| `qa-blocked@test` | customer (`isBlocked: true`) | ✅ | TC-SEC-06 |

Vendor stall: create `vendorStalls/{vendorUid}` with `ownerUid = <qa-vendor uid>`, `isOpen: true`, plus 2–3 products in `vendorStalls/{id}/products/` with known `price` and small `stockQuantity` (e.g. 3) so stock behavior is observable.

---

## 3. Automated suites — what they prove, and their gates

| Suite | Command | Verifies | Gate / metric |
|---|---|---|---|
| Flutter unit/widget/golden | `flutter test` | 368 cases: features, controllers, providers, goldens | **100% pass**; CI gate: line coverage ≥ 40% (current ≈ 41.4% — raise target to 55% before store submission, see §8) |
| Flutter static analysis | `flutter analyze` | lint set incl. `avoid_print`, const prefs | **0 issues** |
| Backend TypeScript | `cd functions && npx tsc --noEmit` | type safety of both backends' shared source | **exit 0** |
| Backend unit (jest) | `npm test` (or `npm run test:rules` for emulator too) | webhook crypto vectors (segmented + legacy, replay, tamper), fee parity with Flutter, transition graph, claim decision, rate-limit math, edge ports parity | **100% pass** — currently **81/81** with emulators |
| Firestore rules (emulator) | `npm run test:rules` | client-create denial on orders, paymentStatus immutability, statusHistory read-through-parent + write denial, ratings gating, role self-escalation denial | **100% pass** |
| CI pipeline | push/PR to `main` | all of the above on windows-latest + debug APK build + secret-hygiene scan + coverage artifact | all steps green |

**Anything in §6 (security) that is `auto` must stay automated** — a regression there is a release blocker by definition.

---

## 4. Functional test cases

### 4.1 TC-ENV — environment & configuration

**TC-ENV-01 · P1 · manual · Production fails closed on missing config**
1. Build with `--dart-define=APP_ENV=production` but omit `FIREBASE_ENABLED`.
2. Launch the app.
Expected: `StartupErrorScreen` with the message naming the missing dart-define — never a silent fallback to mock repositories.

**TC-ENV-02 · P1 · manual · Production fails closed on backend init failure**
1. Run Firebase mode in production env with an invalid `SUPABASE_URL`.
Expected: startup error screen mentioning backend failure; app does not proceed to a half-initialized state.

**TC-ENV-03 · P2 · manual · No conflict markers / no corrupt lock**
1. Fresh `git clone` of the team repo → `flutter pub get`.
Expected: resolves cleanly (regression for the pubspec.lock incident; also `grep -rn "<<<<<<<" .` excluding `node_modules|build|.agents` returns nothing).

### 4.2 TC-AUTH — authentication & account

**TC-AUTH-01 · P1 · manual · Register assigns customer role, cannot self-escalate**
1. Register `qa-customer@test` via email/password.
2. Inspect `users/{uid}` in Firestore console.
Expected: `role: "customer"`. Attempt to edit your own `users/{uid}.role` to `admin` via console-as-app (or Firestore SDK with auth) → denied by rules (auto-covered in rules suite; verify manually once per release).

**TC-AUTH-02 · P1 · manual · Login works for seeded users; wrong password shows friendly error**
Steps: standard. Expected: error message from the typed `OrderFailure`/auth mapping, no stack traces.

**TC-AUTH-03 · P2 · manual · Password change requires re-authentication**
1. Sign in, change password from Security Settings with the **wrong** current password.
Expected: rejected with a credential error; with the correct one → succeeds and session survives per implementation.
Reference: `firebase_auth_repository.dart` re-auth path.

**TC-AUTH-04 · P1 · manual/api · Unverified email cannot place orders**
1. Sign in as `qa-customer-unverified@test`.
2. Add to cart → checkout → place order.
Expected: blocked with "Verify your email before placing orders" — enforced **server-side** (place-order edge function `bearerUid(req, true)`); the client gate is UX only. Also verify a direct callable invocation with the unverified ID token is rejected.

### 4.3 TC-CAT / TC-CART — catalog & cart

**TC-CAT-01 · P2 · manual · Public catalog readable while signed out** — market screen loads stalls/products without auth (world-readable by design; no PII).

**TC-CART-01 · P1 · auto+manual · Quantities, line totals, cart persistence**
1. Add items from two vendors, edit quantities, restart app.
Expected: cart survives (mock: SharedOrderStore; Firebase mode: preferences), totals = Σ price×qty, vendor grouping visible at checkout.

**TC-CART-02 · P2 · auto · Cart merge rule** — merge semantics per `docs/cart_merge_rule.md`; covered by `test/features/cart/*`.

**TC-CART-03 · P2 · manual · Stock cap UX**
1. Set a product's `stockQuantity: 3`.
2. Try adding 5.
Expected: prevented client-side; server enforces the real bound anyway (TC-RACE-01 proves the server side).

### 4.4 TC-CHK — checkout

**TC-CHK-01 · P1 · manual · Multi-vendor order splits per stall**
1. Cart with items from 2 vendors → checkout → place.
Expected: **two** orders created, one per stall; confirmation screen lists both; each has its own status/history; notes per vendor attach to the right order.

**TC-CHK-02 · P2 · manual · Delivery vs pickup fee logic**
- Delivery: subtotal + 49 delivery + 15 service (+29 priority if toggled).
- Pickup: no delivery fee, no priority fee, service fee still applied.
Metric: totals match `FeeConfig` exactly (mirrored server-side — jest asserts parity).

**TC-CHK-03 · P2 · manual · Missing address fallback**
1. Delivery with no saved address.
Expected: falls back to profile default, then placeholder `'San Felipe, Naga City'`. (Known open product decision I4 — verify the behavior is at least visible to the user in the summary before placing.)

**TC-CHK-04 · P1 · manual · Server-side pricing is authoritative**
1. Place an order, note totals.
Expected: the Firestore order's `items[].unitPrice`, fees match the **catalog** prices — the client-sent values are never trusted (placeOrder re-resolves inside the transaction).

### 4.5 TC-PAY — payments (the critical path)

**TC-PAY-01 · P1 · manual · COD end-to-end**
1. Payment method = Cash on Delivery → place order → vendor advances to completed.
Expected: `paymentStatus` flips to `paid` **only at completion** by the vendor (cash rule); webhook never involved.

**TC-PAY-02 · P1 · manual+api · GCash happy path (the H2 regression test)**
1. Firebase + PayMongo test mode. Method = GCash → place order.
2. Expected immediately: confirmation screen shows "Online Payment" section, order row "awaiting your approval", button **Complete Payment**.
3. Tap it → mock GCash page opens (test mode) → approve.
4. Watch the order doc.
Expected: `paymentStatus: processing` at step 2 (intent claimed); webhook `payment.paid` flips to `paid` with `paymentId` + `paidAt` set. Metric: webhook→Firestore flip < **10 s** after approval.

**TC-PAY-03 · P1 · manual · Maya path** — same as TC-PAY-02 with Maya (maps app id `paymaya` → source `maya`).

**TC-PAY-04 · P2 · manual · Card method is honestly unsupported**
1. Method = Card → place order.
Expected: order placed; confirmation shows the card-limitation message directing to GCash/Maya/cash. **No fake success.** No card data is ever stored (verify `CustomerPreferences` only keeps `cardLabel`/last4).

**TC-PAY-05 · P1 · manual · Payment initiation failure → retryable**
1. Temporarily break connectivity after order creation (airplane mode at the confirmation screen).
2. Tap Retry repeatedly.
Expected: per-order failure row with reason; order remains placed with `paymentStatus: pending`; retry succeeds once connectivity returns. No crash, no duplicate orders.

**TC-PAY-06 · P1 · api · Webhook rejects tampered bodies and bad signatures**
Run §2.4's curl with: (a) modified body after signing, (b) wrong secret, (c) garbage header, (d) empty header.
Expected: **401** every time; order unchanged.

**TC-PAY-07 · P1 · api · Webhook replay window**
Re-send a validly-signed request whose `t=` is 6+ minutes old.
Expected: **401** (fail-closed replay guard, 5-min window). Re-send with fresh `t` → accepted.

**TC-PAY-08 · P1 · api · Failed payment does not downgrade settled states**
1. Get an order to `paid` (TC-PAY-02).
2. Send a signed `payment.failed` event for the same intent (§2.4, change `type`).
Expected: ignored (200 `{received:true}` but no state change) — the idempotence guard holds. Send `payment.failed` on a `processing` order → flips to `failed` with `lastPaymentError` recorded.

**TC-PAY-09 · P1 · manual · PayMongo amount limits**
1. Craft carts totalling < PHP 1.00 and (in test mode attempt) > PHP 100,000 for GCash.
Expected: rejected with the specific error message; no intent created; order claim released back to `pending`.

**TC-PAY-10 · P2 · manual · Stuck-processing recovery (the claim watchdog)**
1. Place a GCash order; after intent creation, abandon the mock approval (never approve).
2. Wait > 10 min (or temporarily lower `CLAIM_STALE_MS` in a dev deploy).
3. Initiate payment again for that order.
Expected: backend retrieves the intent: still-open → clear "still pending" error (no second intent); if the intent is canceled at PayMongo → fresh intent allowed; if it silently succeeded → order self-heals to `paid`. **Never** a second live intent for one order (double-payment guard).

### 4.6 TC-ORD — order lifecycle

**TC-ORD-01 · P1 · manual · Vendor state machine**
pending → confirmed → preparing → ready → completed, each with a statusHistory entry stamped with the **acting uid**. Illegal jumps (e.g. pending → completed via the callable) rejected with `failed-precondition`.

**TC-ORD-02 · P1 · manual · Terminal states immutable**
On a completed order, attempt any transition (customer cancel, vendor update).
Expected: "Order is already completed…" everywhere.

**TC-ORD-03 · P1 · manual · Customer cancel window**
1. Place order; cancel within 5 min → succeeds.
2. Place another; wait > 5 min; cancel → `deadline-exceeded` "Cancellation window has expired".
Metric: window = **5 min** (`CANCELLATION_WINDOW_MS`, mirrored in `FeeConfig.cancelWindow`).

**TC-ORD-04 · P1 · manual · Cancel restocks inventory (the M4 regression)**
1. Product stock = 3. Order 2. Stock → 1 (verify in console).
2. Cancel the order.
Expected: stock back to **3** (atomic increment in the same transaction). Reject path: vendor rejects a pending order → stock also returns.

**TC-ORD-05 · P1 · manual+api · Cancel-vs-complete race (the H3 regression)**
1. Two terminals: one as customer poised to cancel, one as vendor poised to complete.
2. Fire both within the same second.
Expected: exactly **one** wins; the loser gets `failed-precondition`/`already-terminal`; the final state is self-consistent (never `completed` + separately `cancelled`, never `paid` stamped onto a cancelled order). Repeat 5× — every run consistent (transactional re-validation).

**TC-ORD-06 · P2 · manual · Cross-stall/vendor isolation**
Vendor A cannot transition orders on Vendor B's stall → `permission-denied`. Customer cannot transition anything except their own cancel.

**TC-ORD-07 · P2 · manual · Customer cannot set estimatedReadyTime**
Cancel with a smuggled `estimatedReadyTime` payload (via direct callable invocation if you can craft it).
Expected: field not persisted (role-gated).

**TC-ORD-08 · P2 · manual · Order history readable by owner, blocked for others**
1. As owner, open order details → history timeline renders.
2. As another customer, attempt reading `orders/{id}/statusHistory/{any}` via SDK.
Expected: owner sees entries; stranger denied (rules authorize through the parent order). Auto-covered in rules suite; verify the UI once per release.

**TC-ORD-09 · P2 · manual · Admin can unstick orders**
1. As `qa-admin@test`, transition a stuck `preparing` order to `cancelled`.
Expected: allowed (graph still binds: no terminal→terminal); audit entry records the admin uid.

### 4.7 TC-RFD — refunds

**TC-RFD-01 · P1 · manual+api · Full refund after webhook-paid order**
1. Get an order `paid` via TC-PAY-02.
2. As the stall owner, refund (no amount = full).
Expected: PayMongo refund created; order → `refunded` (if PayMongo confirms) or `refundPending` (if pending) with `refundId`; statusHistory gains "Refund issued (…)".

**TC-RFD-02 · P2 · manual · Refund guards**
- Non-owner/non-admin → `permission-denied`.
- Unpaid order → "Only paid orders can be refunded".
- Amount > total → rejected; amount < PHP 1.00 → rejected.
- Partial amount → accepted, capped at total.

**TC-RFD-03 · P2 · api · Pending refund settles via webhook**
1. Create a refund that returns `pending` (typical for e-wallets).
2. Send the signed `payment.refunded` webhook (§2.4).
Expected: `refundPending` → `refunded` with `refundedAt`; re-sending the same webhook is idempotent (no double-flip).

**TC-RFD-04 · P1 · api · Double refund race (the claim guard)**
Fire two refund calls simultaneously (owner + admin).
Expected: exactly one PayMongo refund; the loser sees "Only paid orders can be refunded" (claim flipped to `refundPending` first). On PayMongo failure, the claim releases back to `paid`.

### 4.8 TC-REV — reviews

**TC-REV-01 · P1 · manual · Review only after completed order**
Attempt to review a pending order → blocked ("Only completed orders can be reviewed").

**TC-REV-02 · P1 · manual · One review per order**
Submit twice for the same completed order → second gets `already-exists` (deterministic doc id `{orderId}_{uid}`).

**TC-REV-03 · P2 · manual · Aggregate math**
Stall with N reviews at average A; add rating r.
Expected: `averageRating = (A·N + r)/(N+1)`, `totalRatings = N+1` — recomputed transactionally, never drifted.

**TC-REV-04 · P1 · manual · Reviews read REAL data in Firebase mode (the M6 regression)**
1. Submit a review in Firebase mode; note your name/comment.
2. Open the stall's reviews screen (customer side) and the vendor reviews screen.
Expected: your review appears on both — not the seeded mock set (mock only in mock mode).

**TC-REV-05 · P1 · manual · Review written under REAL stall id**
After TC-REV-01, inspect `ratings/{orderId}_{uid}`.
Expected: `vendorId` == the real `stallId` (regression for the mock-id write corruption).

### 4.9 TC-SAL — sales & reports

**TC-SAL-01 · P2 · manual · Ownership-gated report** — owner gets data; other vendor/admin-not-owner → denied. Date range validated (`invalid-argument` on garbage).

**TC-SAL-02 · P2 · manual · Rollup correctness** — complete 2 orders same day at one stall → `salesSummary/{stallId}/daily/{date}` has `orderCount: 2` and revenue = Σ(items+fees). Cancelling afterwards does **not** subtract (known accounting behavior — verify you accept it).

**TC-SAL-03 · P2 · manual · Export** — PDF/Excel exports render the same figures as the screen. Rate limit: > 10 reports/min → `resource-exhausted`.

### 4.10 TC-REC / TC-NOT / TC-KYC — recipes, notifications, KYC

**TC-REC-01 · P2 · manual ·** Recipe catalog loads (Supabase public RLS); "cook with your cart" suggestions reflect current cart contents; saved recipes persist per user.

**TC-NOT-01 · P2 · manual ·** 5-star review triggers the vendor notification (rating modal path); local notifications render on Android 13+ with permission granted; denied permission degrades silently.

**TC-KYC-01 · P2 · manual ·** KYC submission uploads docs to private storage (verify Storage rules: owner-scoped, KYC private); license renewal flow updates `licenseRenewals`; mock mode fakes the 3-second processing delay.

---

## 5. TC-SEC — security negative tests (attempt the attack, expect the wall)

**TC-SEC-01 · P1 · auto (rules suite) + manual spot-check · Direct order creation denied (H1)**
Using the Firestore SDK **as a signed-in customer**, `set orders/new-doc` with a perfectly formed order.
Expected: **PERMISSION_DENIED**. No client-side order creation exists — only the `placeOrder` callable.
Attack variants to spot-check: negative `unitPrice`, `quantity: 0`, spoofed `customerUid`, oversized notes.

**TC-SEC-02 · P1 · auto+manual · paymentStatus forgery blocked**
As the vendor, try `update orders/{id} {paymentStatus: "paid"}` on a GCash order (not completing).
Expected: denied — only cash methods may flip to paid, and only together with `status == 'completed'`.

**TC-SEC-03 · P1 · auto · Audit-log forgery blocked** — any client write to `statusHistory` (including `changedBy: 'system'`) denied.

**TC-SEC-04 · P1 · api · Webhook is the only payment oracle**
Summarized by TC-PAY-06/07/08: unsigned → 401; tampered → 401; stale replay → 401; verified-but-settled → idempotent no-op.

**TC-SEC-05 · P2 · manual/api · Rate limits**
Hammer (as one user): placeOrder >10/min, createPaymentIntent >10/min, createRefund >5/min, orderStatus >60/min, addReview >10/min.
Expected: `resource-exhausted` with the friendly message; recovery after the 60-s window; limits are per-user (a second account is unaffected).

**TC-SEC-06 · P1 · manual · Blocked account enforcement**
As `qa-blocked@test`: place order / transition status → "Your account is blocked" on every trusted path.

**TC-SEC-07 · P1 · auto (CI) + manual · Secrets hygiene**
CI's scan must stay green. Manual: `grep -rEn "sk_live_|sk_test_|service_role" lib functions/src supabase` → only doc-comment/env-var mentions; `git ls-files | grep -E "\.env$|google-services"` → empty.

**TC-SEC-08 · P2 · manual · Release build hygiene**
1. `flutter build apk --release` with production config; open the error-widget path (any widget exception in profile/release).
Expected: generic message only (no stack/exception text). Confirm `password123` prefill absent (debug-only).

**TC-SEC-09 · P1 · deploy checklist · App Check**
Before go-live: enable Play Integrity/App Attest in the Firebase console, then set `APP_CHECK_ENFORCED=true` and verify unattested callable calls fail. **This is the one open security item (M3).**

**TC-SEC-10 · P2 · manual · Supabase edge functions authenticate**
With `verify_jwt=false` (by design), call `place-order` without a `Authorization: Bearer <Firebase ID token>` header and with a garbage token.
Expected: `unauthenticated` both times; only a real, verified token passes.

---

## 6. TC-RACE — concurrency & resilience

**TC-RACE-01 · P1 · manual/scripted · No oversell under concurrent orders**
Two accounts order the last 3 units simultaneously (2+2).
Expected: one succeeds, one gets `out-of-range`; final stock never negative (transactional deduction).

**TC-RACE-02 · P1 · covered by TC-ORD-05** — cancel vs complete.

**TC-RACE-03 · P1 · manual · Double payment-intent prevention**
Tap "Complete Payment"/retry twice in quick succession on one order (or fire two `createPaymentIntent` calls).
Expected: second call rejected with "A payment is already in progress" (claim transaction); exactly one intent id on the order.

**TC-RACE-04 · P1 · covered by TC-RFD-04** — double refund.

**TC-RACE-05 · P2 · manual · Kill-mid-flight recovery** — terminate the function (deploy toggle or breakpoint) between claim and stamp; verify TC-PAY-10's stale-claim path recovers the order.

---

## 7. TC-PERF — performance budgets (manual, mid-range Android device)

| Case | Budget | How to measure |
|---|---|---|
| TC-PERF-01 cold start to splash (mock mode) | < 3 s | `flutter run --profile`, stopwatch from launch |
| TC-PERF-02 market grid with 30+ products, scroll | 60 fps, no jank > 16 ms frames streaks | DevTools timeline / `flutter run --profile` |
| TC-PERF-03 image-heavy stall pages | no reload flicker on back-nav (AdaptiveImage cache) | navigate stall→back→stall |
| TC-PERF-04 callable round-trip (placeOrder, 3 items) | < 2.5 s p95 on good network | timestamp logs around the call |
| TC-PERF-05 webhook → Firestore flip | < 10 s | TC-PAY-02 step 4 |
| TC-PERF-06 vendor orders screen with 50 orders | < 2 s first paint, smooth scroll | seed 50 docs, profile |

---

## 8. Metrics & gates summary

| Metric | Current | Gate | Target (store submission) |
|---|---|---|---|
| Flutter tests | 368, all passing | 100% | grow with payment-path widget tests |
| Backend jest | 81, all passing | 100% | keep parity tests for both stacks |
| `flutter analyze` | 0 issues | 0 | 0 |
| `tsc --noEmit` | exit 0 | 0 errors | 0 |
| Line coverage (CI-enforced) | ≈ 41.4% | **≥ 40%** | **≥ 55%** |
| P1 manual cases passing | — | **100%** | 100% |
| P2 executed cases passing | — | ≥ 95% | ≥ 98% |
| Webhook rejection (unsigned/tampered/stale) | — | 100% rejected | 100% |
| Double-payment / double-refund paths | guarded | 0 occurrences in TC-RACE-03/04 × 5 runs | same |
| Oversell under concurrency | guarded | 0 in TC-RACE-01 × 5 runs | same |
| Cancel window accuracy | 5 min ± clock skew | server-enforced | same |
| Secrets in repo | none | stays none (CI scan) | same |

**Severity scale for failures:** Critical = money loss / data corruption / auth bypass (any TC-SEC/TC-PAY/TC-RACE failure) · Major = feature broken on primary path · Minor = cosmetic/degradation.

**Exit criteria for a release candidate:** §3 suites green + all P1 green + P2 ≥ 95% + no open Critical/Major + TC-SEC-09 (App Check) done or explicitly signed off as post-launch fast-follow.

---

## 9. Traceability — audit findings → proving tests

| Audit finding (docs/audit-2026-08-22.md) | Fixed by | Proven by |
|---|---|---|
| H1 client order creation w/ forged prices | rules default-deny | TC-SEC-01 (auto in rules suite) |
| H2 payments unwired | PayMongoService + checkout UI | TC-PAY-02/03/04/05 |
| H3 transition race | transactional applyStatusTransition | TC-ORD-05 |
| M1 webhook header format | segmented verify + replay window | TC-PAY-06/07, jest vectors |
| M2 duplicate intents | claim + releaseClaim | TC-RACE-03, claimDecision unit tests |
| M4 no restock on cancel | increment in transition tx | TC-ORD-04 |
| M5 refund pending state | refundPending + webhook flip | TC-RFD-01/03 |
| M6 mock reviews in prod | repository-backed providers | TC-REV-04/05 |
| M7 no admin path | admin shares vendor path | TC-ORD-09 |
| I3 unrate-limited report | rateLimit + App Check opt | TC-SAL-03 |
| L4 release error leak | kReleaseMode message | TC-SEC-08 |
| (2nd pass) failed-event downgrade | guard in both webhook ports | TC-PAY-08 |
| (2nd pass) stuck processing | claimDecision + intent inspection | TC-PAY-10, TC-RACE-05 |
| (2nd pass) refund TOCTOU | refund claim tx | TC-RFD-04 |
| (2nd pass) history reads denied | parent-order read rule | TC-ORD-08 (auto) |

**When you touch these areas, run the mapped cases before opening the PR.**

---

## 10. Regression quick-set (pre-PR, ~20 minutes)

1. `cd functions && npx tsc --noEmit && npm run test:rules` (needs JDK)
2. `flutter analyze && flutter test`
3. Manual: TC-PAY-02 (GCash end-to-end), TC-ORD-04 (restock), TC-SEC-01 (direct write denied), TC-REV-04 (real reviews)
4. If rules or webhook code changed: TC-PAY-06/07/08 via §2.4 curl
