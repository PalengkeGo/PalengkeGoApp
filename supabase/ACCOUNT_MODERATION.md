# Account moderation

On 2026-10-26, migration `20261026010000_account_moderation.sql` and the updated
`admin-portal` were deployed to `jvpplxlcucuzmbtbmtah`. After user approval, the
16 Firebase-authenticated app functions importing the shared account-access
check were also redeployed. Existing authentication settings were preserved.

The migration was applied from an isolated directory after a dry run showed
only this migration. Older pending migrations were not applied. Reconcile the
duplicate `20261018010000` filenames and pending migration history before any
bulk database push. In particular, the older report-evidence migration replaces
the audit action constraint; retain the new moderation action values if applying
that migration later.

- Account Details saves administrative notes privately. Saving notes never
  changes access or sends a notification.
- Suspend, lift, block, and unblock use the service-only `moderate_account` RPC.
  Each operation, audit event, and optional recipient notification commits in
  one transaction. The verified admin identity comes from the Edge Function.
- Suspensions use UTC timestamps and are effective on the half-open interval
  `[starts_at, ends_at)`. Access checks expire automatically; no scheduler is
  needed. Historical records remain available after expiry or early lifting.
- Suspension internal notes stay private. The notification contains only the
  reason and schedule, displayed in Philippine time. Block/restore notices are
  generic. Notices use the existing customer/vendor Notifications screens.
- Account status and notice inserts use Supabase Realtime for foreground
  updates. The mobile app keeps a 2.5-second refresh as a recovery fallback.
- Phone push delivery uses Firebase Cloud Messaging. Apply
  `20261026020000_account_realtime_push.sql`, deploy `account-device-token` and
  the updated `admin-portal`, and keep `FIREBASE_SERVICE_ACCOUNT` configured.
  The app must have notification permission and register its device token.
- Blocked users see the non-dismissible restriction screen over a dimmed,
  non-interactive app. Suspended users see the restriction notice and an
  immediate in-app warning when the moderation event arrives.
- History uses real registration/order records and admin audit events. Violation
  history lists recorded warnings, suspensions, and blocks, not unreviewed
  complaints or sample violations.
- The shared Edge Function gate and chat authorization reject active restricted
  users. New orders also reject a restricted customer or stall holder at the
  database boundary. Existing legacy direct-table policies outside these paths
  are not comprehensively hardened by this change.

Validation: 107 admin tests passed; analysis has no issues; seven backend tests
passed. A final focused account test and isolated SQL test also passed after the
last adjustments. Live checks confirmed the migration, private-note grants,
service-only mutation permission, and HTTP 401 for an unsigned admin request.
No real user was suspended or blocked for testing. A signed-in end-to-end
customer/vendor smoke test is still needed.
