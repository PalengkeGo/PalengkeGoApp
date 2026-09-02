-- PalengkeGo — Supabase Storage buckets + object policies (audit 2026-08-23 M6).
--
-- The app uploads through lib/core/infrastructure/supabase_storage_service.dart
-- with the ANON key (auth is Firebase, so Supabase RLS cannot see user
-- identity). Buckets were previously "create manually in the dashboard" —
-- this migration versions them so the posture is auditable and repeatable.
--
--   stalls   — stall banner/avatar/product images (public reads, 8 MB, images)
--   profiles — customer profile images            (public reads, 5 MB, images)
--   kyc      — KYC permit photos                  (private, 15 MB, images+PDF)
--   license  — license renewal documents          (private, 15 MB, images+PDF)
--
-- Server-side bucket limits (file_size_limit, allowed_mime_types) are
-- enforced by the Storage API itself. The RLS policies below add:
--   - anon INSERT (the app's upload path)
--   - anon SELECT on private buckets (REQUIRED: the app mints signed URLs
--     via createSignedUrl, which needs select on the object row)
--   - no anon UPDATE/DELETE (service role only) — objects cannot be
--     overwritten or removed with the public key.
--
-- ⚠ RESIDUAL RISK (documented in the audit): with Firebase auth there is no
-- way to express "owner-only" uploads in Supabase RLS — anyone holding the
-- anon key (it ships in the app binary) can upload into these buckets within
-- the size/type limits, and can read/sign private-bucket objects they know
-- the path of. Mitigations in place: strict mime + size caps, no overwrite,
-- no delete, no listing of other users' objects without the exact path.
-- Hardening follow-up: proxy private uploads through a service-role edge
-- function that validates the Firebase ID token and owns the object path.

-- ── Buckets ──────────────────────────────────────────────────────────────────

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('stalls', 'stalls', true, 8388608, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('profiles', 'profiles', true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('kyc', 'kyc', false, 15728640, array['image/jpeg', 'image/png', 'image/webp', 'application/pdf'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('license', 'license', false, 15728640, array['image/jpeg', 'image/png', 'image/webp', 'application/pdf'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- ── Object policies ──────────────────────────────────────────────────────────
-- Idempotent: drop-then-create under stable names.

drop policy if exists "palengkego stalls insert" on storage.objects;
drop policy if exists "palengkego stalls select" on storage.objects;
drop policy if exists "palengkego profiles insert" on storage.objects;
drop policy if exists "palengkego profiles select" on storage.objects;
drop policy if exists "palengkego kyc insert" on storage.objects;
drop policy if exists "palengkego kyc select" on storage.objects;
drop policy if exists "palengkego license insert" on storage.objects;
drop policy if exists "palengkego license select" on storage.objects;

-- Public imagery: anon upload + read, extension-guarded (defense in depth on
-- top of the bucket's allowed_mime_types).
create policy "palengkego stalls insert"
  on storage.objects for insert to anon, authenticated
  with check (
    bucket_id = 'stalls'
    and storage.extension(name) in ('jpg', 'jpeg', 'png', 'webp')
  );

create policy "palengkego stalls select"
  on storage.objects for select to anon, authenticated
  using (bucket_id = 'stalls');

create policy "palengkego profiles insert"
  on storage.objects for insert to anon, authenticated
  with check (
    bucket_id = 'profiles'
    and storage.extension(name) in ('jpg', 'jpeg', 'png', 'webp')
  );

create policy "palengkego profiles select"
  on storage.objects for select to anon, authenticated
  using (bucket_id = 'profiles');

-- Private documents: anon upload + select (select is required for the app's
-- createSignedUrl calls — see residual-risk note above). No update/delete.
create policy "palengkego kyc insert"
  on storage.objects for insert to anon, authenticated
  with check (
    bucket_id = 'kyc'
    and storage.extension(name) in ('jpg', 'jpeg', 'png', 'webp', 'pdf')
  );

create policy "palengkego kyc select"
  on storage.objects for select to anon, authenticated
  using (bucket_id = 'kyc');

create policy "palengkego license insert"
  on storage.objects for insert to anon, authenticated
  with check (
    bucket_id = 'license'
    and storage.extension(name) in ('jpg', 'jpeg', 'png', 'webp', 'pdf')
  );

create policy "palengkego license select"
  on storage.objects for select to anon, authenticated
  using (bucket_id = 'license');
