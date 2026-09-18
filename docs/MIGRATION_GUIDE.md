# Migration Guide — Firebase to Supabase (Orders, Payments, Reviews)

**What changed:** Orders, payments and reviews now run on Supabase instead of Firebase.
Firebase is still used for **login only** (email/Google, ID token).

**Why:** Supabase edge functions are cheaper and already used for storage. Same logic, just called differently.

**How it works now:**
- App gets Firebase login token (`getIdToken()`)
- Calls Supabase: `POST https://<your-project>.supabase.co/functions/v1/place-order` (and `update-order-status`, `cancel-order`, `request-refund`, `process-refund`, `add-review`, `create-payment-intent`)
- Header: `Authorization: Bearer <Firebase token>`
- Supabase verifies the token and does the same stock/price checks as before.

**What was changed in code:**
- New: `lib/features/orders/data/supabase_order_repository.dart` (does the http calls)
- Changed: `lib/features/orders/application/order_provider.dart` → uses Supabase repo
- Changed: `lib/features/vendors/data/firebase_vendor_repository.dart` (reviews), `lib/core/infrastructure/paymongo_service.dart` (payments), `lib/features/checkout/application/checkout_controller.dart` (removed old Firebase callable code)
- Old: `lib/features/orders/data/firebase_order_repository.dart` kept but marked deprecated — for rollback
- New: `supabase/functions/_shared/orders.ts`, 7 edge function folders, `supabase/migrations/20260915...` (107 recipes)

**How to deploy:**
```bash
supabase db push          # pushes the 2 new recipe migrations
supabase functions deploy place-order update-order-status cancel-order request-refund process-refund add-review create-payment-intent --no-verify-jwt
```

**Rollback:** Keep `functions/src` deployed for 1 week. If Supabase has issues, revert `order_provider.dart` to return `FirebaseOrderRepository` and redeploy Flutter.

**Recipes:** Gaps 113-160 filled, remaining 59 appended after max. Verify: `SELECT id, title FROM public.recipes ORDER BY id;`
