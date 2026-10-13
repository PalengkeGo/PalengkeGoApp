-- Shared fields and identity constraint used by the trusted admin-portal
-- Edge Function. Admin requests are authenticated with Firebase and mapped
-- to exactly one Supabase administrator record.
ALTER TABLE public.system_announcements
  ADD COLUMN IF NOT EXISTS image_url text;

CREATE UNIQUE INDEX IF NOT EXISTS admins_user_id_unique
  ON public.admins(user_id);
