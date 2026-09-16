-- PalengkeGo — Storage lock-down (audit 2026-09-13 C1 + M1).
--
-- The 2026-08-23 migration granted the ANON key INSERT + SELECT on every
-- bucket. The private-bucket SELECT was believed to only allow path-known
-- reads; in fact a bare SELECT policy on storage.objects also permits
-- LISTING and object signing, so anyone holding the anon key (it ships in
-- the app binary) could enumerate and download every KYC permit and license
-- document. Public-bucket INSERT also allowed unlimited anonymous hosting.
--
-- This migration REMOVES all anon object policies. After it runs:
--   - NO direct Storage API writes or reads with the anon key succeed.
--   - Public imagery (stalls/profiles) remains readable via public URLs
--     (/object/public/...), which bypass RLS by design.
--   - Uploads and private-bucket reads go through the trusted edge
--     functions `storage-upload` and `storage-sign`, which verify the
--     caller's Firebase ID token, enforce `{uid}/...` path ownership and
--     per-bucket extension allowlists, and use the service role key.
--     (supabase/functions/storage-upload, supabase/functions/storage-sign)

-- ── Drop the anon object policies ──────────────────────────────────────────

drop policy if exists "palengkego stalls insert" on storage.objects;
drop policy if exists "palengkego stalls select" on storage.objects;
drop policy if exists "palengkego profiles insert" on storage.objects;
drop policy if exists "palengkego profiles select" on storage.objects;
drop policy if exists "palengkego kyc insert" on storage.objects;
drop policy if exists "palengkego kyc select" on storage.objects;
drop policy if exists "palengkego license insert" on storage.objects;
drop policy if exists "palengkego license select" on storage.objects;

-- Defense in depth: if any older hand-created policies exist (the buckets
-- were originally created manually in the dashboard), drop those too.
drop policy if exists "public read stalls" on storage.objects;
drop policy if exists "public read profiles" on storage.objects;
drop policy if exists "anon upload stalls" on storage.objects;
drop policy if exists "anon upload profiles" on storage.objects;

-- Bucket definitions (public flags + size/mime caps) are unchanged from
-- 20260823000000_storage_buckets.sql — the Storage API still enforces
-- file_size_limit and allowed_mime_types on the signed-upload PUT, so the
-- server-side caps survive the lock-down.

comment on table storage.objects is
  'PalengkeGo 2026-09-13: no anon policies — all uploads/reads via storage-upload/storage-sign edge functions (service role, Firebase-token verified).';
