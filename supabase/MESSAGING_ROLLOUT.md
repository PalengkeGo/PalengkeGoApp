# Messaging backend hardening

## Verified remote state (2026-10-21)

Linked project: `jvpplxlcucuzmbtbmtah`.

- All 28 existing local migration versions through `20261018020000` are recorded remotely.
- `20261018010000` is named `repair_user_carts_schema`, not the incoming messaging migration. Do not repair or rename that deployed entry.
- `conversations` and `messages` already exist outside the recorded chat migration history. Their column types match the incoming migration.
- Both tables previously had unrestricted `FOR ALL` policies. Deployment replaced them with participant-only SELECT policies and revoked direct client writes.
- There were zero duplicate `(stall_id, customer_uid)` pairs. The new unique index therefore has no known data conflict.
- Two messages have attachment values; neither uses a public Supabase Storage URL. Existing attachments/messages are retained.
- The migration dry run lists only `20261021010000_in_app_messaging.sql` and `20261021020000_secure_messaging.sql`. No history repair is needed.

The user confirmed Firebase integration is enabled for `palengkegodb` with a dashboard screenshot. Chat migrations `20261021010000`, `20261021020000`, and `20261021040000` are now deployed and verified in migration history. The last removes direct anon EXECUTE grants inherited from hosted defaults. Live checks confirm anonymous message reads and RPC sends are denied, authenticated RPC sends remain available, and the attachment bucket is private. `chat-auth` has been deployed to resolve the reported missing-function 404; an unsigned request now returns the expected 401 `unauthenticated`. Signed-in provisioning still needs a live smoke test.

During this work, a separate `20261021030000_vendor_complaint_realtime.sql` migration appeared in the shared workspace. It was not created or reviewed as part of chat hardening. Re-run the dry run and review that migration separately before using a bulk database push.

## Deployment order

1. Confirm/add the Firebase Third-party Auth integration for **palengkegodb** in the linked Supabase project's Authentication settings. The corresponding local config is in `supabase/config.toml`. Avoid pushing unrelated project defaults wholesale.
2. `chat-auth` is deployed. It verifies the Firebase bearer token, checks the user's registered/unblocked account, and assigns only that caller the `authenticated` Postgres role claim while preserving other custom claims. It uses the existing `FIREBASE_SERVICE_ACCOUNT` secret; confirm the secret contains a valid Firebase Admin service account during the signed-in smoke test. The app refreshes its token after provisioning.
3. Completed: applied the two chat migrations and the anonymous-grant follow-up (`20261021040000`) using an isolated deployment directory that excludes the unrelated `20261021030000` migration. For future deployments, recheck migration history and duplicate pairs. Use `supabase db push --linked` only when every migration listed by its dry run has been reviewed, including any unrelated work in this shared checkout. The first migration reuses existing tables and removes permissive policies; the second grants participant-only reads, installs transaction RPCs, reconciles unread totals from messages, and creates the private attachment bucket. Existing rows are not deleted.
4. Deploy the updated app in the same rollout. Older clients perform direct writes and will be denied after hardening. The updated client sends create/send/read actions through RPCs and authenticates its dedicated chat client with Firebase.
5. Deploy the updated Firestore rules if Firestore is still enabled. The unused Firestore chat permissions were removed; this app stores chats in Supabase.
6. Smoke-test with a customer, the actual stall owner, and an unrelated account: conversation creation, both-direction messages, unread totals, read receipts, reconnect/token refresh, private typing and photo access. Verify the public API key cannot read chat tables or invoke mutation RPCs. These live checks require signed-in test accounts and were not performed by the local tests.

Do not restore the old permissive policies as a rollback. If rollout fails, keep chat denied while correcting the auth/client configuration; existing chat data remains intact.

## Concurrency and identity

All client writes are revoked. RPCs derive the actor and role from a verified Firebase JWT and database ownership, not caller-supplied sender/reader fields. Reads require the expected issuer/audience, an unblocked user, and membership in the conversation. Typing uses private Realtime channels; new photo uploads use `chat-attachments` rather than the public stall bucket.

Both send and mark-read lock the conversation row before changing messages or totals. A send increments the current counter in SQL and commits the message and summary together. A read receipt marks incoming messages and resets only the reader's counter in the same transaction. Different conversations can proceed independently.

## Checks

Latest local verification: 29 Flutter tests passed, Flutter analysis found no issues, the messaging SQL test passed, and the Edge Function type check passed.

```powershell
npx --yes --package=deno deno test --allow-read --allow-env supabase/tests/messaging_test.ts
npx --yes --package=deno deno check --config supabase/functions/deno.json supabase/functions/chat-auth/index.ts
flutter test test/features/messages test/order_confirmation_screen_test.dart
flutter analyze --no-pub
supabase migration list --linked
supabase db push --linked --dry-run
```

The PostgreSQL test uses an isolated PGlite engine, not the linked database. It exercises access denial, verified identity, role spoofing prevention, queued sends, read receipts, rollback, private room/storage policies, and preservation/reconciliation of existing rows. It does not simulate multiple independent PostgreSQL connections or validate hosted Firebase/Realtime integration.

Reference: [Supabase Firebase Auth integration](https://supabase.com/docs/guides/auth/third-party/firebase-auth).
