# Supabase connection audit — 2026-09-30

## Deployment state

Local fixes are not deployed. Do not release this Flutter build before applying
`20260930010000_app_data_connections.sql` and deploying the matching functions:
`place-order`, `read-orders`, `update-order-status`, `cancel-order`, `add-review`,
`request-refund`, `process-refund`, `save-stall`, `save-address`.
Do not blanket-deploy all functions: the local payment-intent implementation is a placeholder
and may differ from the deployed version.

Live checks used migration history, function metadata, table columns, constraints,
RLS policies and publication metadata only. No live records were edited or deleted.
The environment and test accounts have not been confirmed for end-to-end writes.

## Verified failures and local repairs

| Flow | Finding | Repair |
| --- | --- | --- |
| Order list | SQL subquery in PostgREST filter is invalid; customer/stall FKs were dropped; customer reads have no RLS policy | Firebase-authenticated read-orders resolves account IDs server-side; no local fallback |
| Checkout | Client prices trusted; partial writes and swallowed failures; fallback could create duplicate/fake orders | Atomic server transaction prices from products, checks stock, preserves fractional kg, saves items/history/customer/notes/fees together |
| Order statuses | App enum names violate live DB checks | Map completed/outForDelivery to delivered/out_for_delivery; transactional ownership/state validation and restocking |
| Product saves | Failed writes reported success; name-based fallback could modify a different product | Stable product and owner IDs, confirmed rows, propagated errors |
| Catalog | Local data could resurrect deleted/hidden products and override stock | Online catalog is authoritative, including empty results and zero stock |
| Profiles | Local cache wins over saved remote profile; write errors swallowed | Read remote profile; confirm writes before success |
| Stall settings | Hours only local; availability success before write; fallback self-approved stalls | Authenticated atomic profile/schedule save; no self-approval; wait before success |
| Reviews | UI writes to mock repository; missing customer FK breaks edge lookup; scores never roll up | Invoke add-review; explicit ownership/completed-order checks; real ratings reads and aggregate trigger |
| Addresses | Saved only to device | Authenticated save/read/delete; customer identity resolved server-side; wait before UI success |
| Refresh across devices | Only recipes are published to Realtime | Foreground refresh every 15 seconds plus refresh on resume; existing vendor order polling retained |
| Refund state | Missing columns, functions undeployed, incorrect status values | Matching schema and state transaction; online money refunds explicitly rejected until payment provider processing is wired |
| Demo catalog | Named stalls come from bundled seed data | App seed lists empty; sample stalls/products/reviews moved under test only; stale local demo products ignored |

## Remaining rollout blockers and intentionally local features

- Existing users/products/orders/storage anonymous RLS write policies are permissive.
  Firebase identity is not passed to PostgREST as a Supabase session. The new private
  operations use verified Firebase Edge Functions, but existing direct profile/product
  writes still need an authenticated RLS or trusted-function security rollout.
- Local `create-payment-intent` returns synthetic IDs, and the local payment webhook
  matches a payment-intent ID against order_id. Neither is a verified working payment
  integration. Payment-provider checkout/refunds need a separate live test and repair;
  no real money movement was attempted.
- License renewals have no live table and the repository is mock. Connected mode now
  reports that renewal submission is unavailable instead of falsely claiming submission.
- Favorites, saved recipes, blocked stalls and connected payment account preferences
  remain device-local. They do not synchronize through Supabase.
- Notifications are mostly generated locally. The product promo notification payload
  does not match the notifications table. Cross-device push delivery is not verified.
- Cart has a local fallback; remote cart failures can be hidden by it. Cross-device cart
  merge and concurrent edits still need integration testing.
- Old migrations are not fully replayable as-is: the order ID migration omits converting
  ratings.order_id although the live DB already has that conversion. The isolated test
  explicitly reconstructs that observed live state before applying the new migration.
- Remote scheduled auto-open/close needs a server scheduler. Saving hours now persists
  the schedule; the device timer is disabled in connected mode to avoid fake local state.

## Validation

`flutter analyze --no-pub`

`flutter test --no-pub test/core/infrastructure/supabase_connections_test.dart test/features/market/no_demo_catalog_test.dart`

`npx --yes --package=deno deno test --allow-read --allow-env supabase/tests/app_connections_test.ts`

The SQL check runs in isolated in-memory PostgreSQL using PGlite, not the linked project.
It exercises checkout/stock rollback, fractional quantities, ownership, transitions,
restocking, rating aggregates, schedule rollback, addresses and refund state.

Before declaring complete, deploy the reviewed subset to a confirmed environment and
use separate customer/stall-holder test accounts to save/reload each flow, place a test
cash order, update it from the other device, and verify the first device refreshes.

## Customer and stall holder UI updates

Pull-to-refresh awaits actual provider reloads on customer market/order pages and
stall holder dashboard/order tabs, including empty and failed vendor order lists.
The dashboard sales summary shares the refreshed vendor order data.
Customer review cards scroll continuously and preserve content across background
reloads. Reduced-motion settings stop automatic movement.
Customer stall cards/profiles show a Philippine-time closing countdown only in
the final hour of saved operating hours, including overnight shifts. Schedule
reads require the public SELECT policy in the pending migration above.

Regression checks: `test/features/vendors/vendor_refresh_test.dart` and
`test/features/vendors/customer_stall_experience_test.dart`.
