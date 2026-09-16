# Security Task Handoff — 2026-09-13

Owner: ___  ·  Context: docs/CHANGELOG.md entry **[September 13, 2026] — Security Hardening** (read first — it explains what was already fixed and the deploy order).

Working rules for every task below:
- Deploy order matters: `firebase deploy --only functions` BEFORE shipping any new client build (the client now calls those callables directly).
- Gates: `dart analyze` (run interactively — it can hang in some runners/CI), `flutter test`, `cd functions && npm test`.
- Two standing verifications after any Supabase deploy:
  - `curl -X POST "https://<project>.supabase.co/storage/v1/object/list/kyc" -H "apikey: <anon>" -H "Content-Type: application/json" -d "{\"prefix\":\"\"}"` must return **4xx**.
  - One PayMongo **test-mode** GCash order end-to-end; the webhook must flip `paymentStatus` → `paid`.

---

## Task 1 — Enforce App Check (audit H2 / old M3) — effort: ~2h + 1 day monitoring

**Why:** the trusted callables currently accept ANY authenticated Firebase account. Email verification does not stop bulk abuse: disposable/catch-all email domains automate verification, and Google Sign-In accounts always carry `email_verified = true` anyway (bulk Google accounts are cheap). App Check proves the request came from the genuine app binary, making scripted multi-account abuse structurally impossible instead of merely rate-limited. Damage being prevented: order spam / stock lock churn (place-cancel cycles), notification spam, Firebase billing noise.

**Current state (already done, don't redo):** the Flutter app activates App Check at startup with `AndroidPlayIntegrityProvider` (release) / `AndroidDebugProvider` (debug) — `lib/core/infrastructure/firebase_service.dart`. Every callable in `functions/src` already declares `enforceAppCheck: APP_CHECK_ENFORCED`, which reads env var `APP_CHECK_ENFORCED` (default OFF) — `functions/src/security.ts`.

**Steps:**
1. Firebase console → App Check → register the Android app for **Play Integrity**. Play Integrity validates against the app's signing cert: if distributing through Play, the Play-managed key applies automatically; if sideloading a self-signed release APK, register that cert's SHA-256 in the console first.
2. Keep debug builds on the debug provider. If CI/emulator runs hit real functions (they shouldn't — jest uses emulators which ignore App Check), register a debug token in the console.
3. Enable enforcement: add `APP_CHECK_ENFORCED=true` to `functions/.env` (do NOT commit that file — it may hold PayMongo secrets) and `firebase deploy --only functions`. Do NOT flip before step 1–2 are confirmed, or every real user gets rejected.
4. Monitor: Firebase console → App Check → metrics (share of verified vs unverified requests) + Cloud Logging for `failed-precondition`/`permission-denied` spikes on the callables. Keep monitoring ~24h; if real users get rejected, the console metrics will show it — the client silently retries token refresh (`setTokenAutoRefreshEnabled(true)` is already set).
5. Scope note: App Check covers the Firebase callables ONLY. The Supabase edge functions (`storage-upload`, `storage-sign`, `paymongo-webhook`) run `verify_jwt = false` and authenticate via Firebase ID-token verification themselves — do not chase App Check there, it does not apply.

**Verify:** real-device order + review flow still works after the flip; a scripted callable call without an App Check token (e.g. plain REST to the callable URL) is rejected. Jest suite still green (emulators unaffected).

---

## Task 2 — ✅ DONE IN REPO 2026-09-13 — Split `vendorStalls` into public catalog + private record (audit M2)

**Status:** implemented — rules, callables (`approveKyc`, `addReview`, `placeOrder`), client repos (vendor/market/order), idempotent backfill script (`functions/scripts/backfill-stall-catalog.js`), and rules tests (public read, private denial, badge/aggregate tamper denial). See CHANGELOG [September 13, 2026].

**Remaining deploy steps (must land together):**
1. `firebase deploy --only firestore:rules`
2. `GOOGLE_APPLICATION_CREDENTIALS=… node functions/scripts/backfill-stall-catalog.js` (once, against production)
3. `firebase deploy --only functions`
4. Ship the client — it reads `stallCatalog` from the moment it runs.

**Behavior notes:** `MarketVendor.stallNumber`/`marketSection` are now null in the public listing (admin allocation data went private — the customer-facing `location` string still shows where the stall is). The verified badge comes from `stallCatalog.isKYCApproved`, stamped only by `approveKyc`.

<details><summary>Original task spec (kept for context)</summary>

**Why:** `vendorStalls/{stallId}` is `allow read: if true` — the entire internet (not just app users) can read EVERY field: `ownerUid` (a permanent identifier linking a real vendor to a Google account), KYC state, `licenseStatus`/`licenseExpiryDate`, and admin-assigned `stallNumber`/`floorNumber`/`section`. Rules cannot filter fields (all-or-nothing per document), and `ownerUid` cannot simply be deleted — the security rules themselves (`ownsStall()` in `firestore.rules`) and the callables (`stallOwnerUid()`) read it from this doc to authorize vendor writes. With real vendor data + an LGU attached, this becomes a Data Privacy Act problem (data minimization) and a vendor-phishing enabler ("your MEPO license shows expired, renew here").

**Design:** sibling collection `stallCatalog/{stallId}` — SAME document IDs.

- `stallCatalog` (public, `read: if true`): `name`, `category`, `averageRating`, `totalRatings`, `bannerImage`, `avatarImage`, `isOpen`, `location`. This is exactly the field set `FirebaseVendorRepository.getVendorProfile` consumes.
- `vendorStalls` (owner + admin read only): everything else (`ownerUid`, KYC/license state, stall allocation, vendor settings). Products subcollection keeps its own `allow read: if true` — rules don't cascade from parent to subcollection, so give it its own statement if the parent's read tightens.

**Steps:**
1. `firestore.rules`: add `match /stallCatalog/{stallId} { allow read: if true; allow write: if false; }`. Tighten `vendorStalls` read to `signedIn() && (request.auth.uid == stallId || isAdmin())`. Keep `vendorStalls/{stallId}/products` public-read.
2. Backfill script (`functions/scripts/`): for every `vendorStalls` doc, upsert the `stallCatalog` doc with the public fields. Idempotent (re-runnable).
3. `functions/src/admin.ts` — `approveKyc`: create/update BOTH docs in the same transaction (catalog doc gets name/category placeholders the vendor fills in later; check how the client currently writes name/category to the stall doc and mirror that path).
4. `functions/src/reviews.ts` — `addReview`: the rating aggregate moves to `stallCatalog` (read `averageRating`/`totalRatings` from and write to the catalog doc inside the same transaction). Update the `vendorStalls` rules deny-list accordingly (rating keys no longer exist there).
5. Client: `FirebaseVendorRepository.getVendorProfile` → read `stallCatalog`. Audit market/search/home providers for direct `vendorStalls` reads and switch them. `getVendorStall` (vendor's own dashboard) stays on `vendorStalls` — vendors can read their own doc.
6. MEPO admin portal (separate repo): admin reads on `vendorStalls` still work; anything the portal renders publicly must switch to the catalog. Flag to the portal's maintainer.
7. Rules tests: catalog public-read positive test; `vendorStalls` read denial for a signed-in non-owner; existing H1 privileged-field tests still pass.

**Verify:** logged-out market browsing works; a signed-in non-owner cannot read a `vendorStalls` doc (rules emulator test); review aggregate still updates on the UI after `addReview`; jest + flutter suites green.

---

## Task 3 — First real signed-upload runtime check (closes the last "should work") — effort: 30 min

**Why:** the new upload path (client → `storage-upload` edge function → 10-min signed upload URL → device PUTs bytes directly to Storage with the `x-supabase-upload-token` header) was written against the documented Storage API contract and cross-checked against the installed package versions, but has never touched the live service. No static analysis can prove a live API's behavior — only a real upload can.

**Steps:**
1. Prerequisites (from the CHANGELOG deploy checklist): `supabase db push` (lock-down migration), `supabase functions deploy storage-upload storage-sign`, `FIREBASE_SERVICE_ACCOUNT` set as a Supabase secret.
2. Run vendor onboarding from the app and upload one KYC photo.
3. Read the failure mode if it fails — the error body says exactly which step disagreed:
   - Edge function 500 "Storage service is not configured" → `SUPABASE_URL`/`SUPABASE_SERVICE_ROLE_KEY` missing (auto-injected on hosted Supabase; if self-hosted, set them manually).
   - PUT returns 400 → header/contract mismatch with the project's Storage version → send the response body back to the team; fallback fix is a small `storage-upload` variant that accepts the file body directly (service-role upload) with no client change.
   - PUT returns 403 → signed-URL token expired (10 min) or path mismatch.
4. Also verify the read side: the same vendor (or an admin) opens the document and gets a 1-hour URL via `storage-sign`.
5. Run the anon-lockdown curl (standing verification above) — it must now fail with 4xx.

**Verify:** object exists in the Supabase dashboard under `kyc/{uid}/…`; the old direct-anon upload (Storage API with only the anon key) is rejected.

---

## Task 4 — Lock down `users` self-registration fields (audit Low) — effort: ~1h

**Why:** `firestore.rules` `users/{uid}` create validates `role == 'customer'`, `isBlocked == false`, `isVerified == false` — but accepts ANY other fields. A user can stash arbitrary junk up to the 1 MB doc cap in their own profile. No privilege escalation, just hygiene.

**Steps:**
1. In `firestore.rules` `match /users/{uid}`, extend `allow create` with a key allowlist:
   `&& request.resource.data.keys().hasOnly(['uid','email','displayName','role','phoneNumber','profilePhoto','isVerified','isBlocked','createdAt','updatedAt'])`
2. Check the client's actual `_writeUserDoc` payload (`lib/features/auth/data/firebase_auth_repository.dart`) matches exactly — add any field it writes.
3. Optionally tighten `allow update` the same way using `request.resource.data.diff(resource.data).affectedKeys().hasOnly([...mutable fields...])` — mutable today: `displayName`, `phoneNumber`, `profilePhoto`, `updatedAt` (the protected `role`/`isBlocked`/`isVerified`/`email` diff-guard already exists).
4. Add rules tests: create with an extra junk field → denied; normal registration → allowed; edit profile (displayName/phoneNumber) → allowed.
5. Gotcha: any FUTURE client field must be added to the allowlist or registration breaks — put that warning in a rule comment.

**Verify:** `cd functions && npm run test:rules` (emulator suite) green; manual registration + profile edit still work in the app.

---

## Priority order

1 (App Check) and 3 (upload check) gate a real deployment. 2 (catalog split) gates real vendor data / LGU endorsement. 4 is hygiene — fold into any rules-touching PR.
