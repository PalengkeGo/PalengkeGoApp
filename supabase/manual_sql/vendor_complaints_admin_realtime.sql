-- Run once in Supabase Dashboard > SQL Editor.
-- Complaint identity columns match the Firebase-compatible text IDs in public.
CREATE TABLE IF NOT EXISTS public.vendor_complaints (
  complaint_id text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  reporter_user_id text NOT NULL,
  stall_holder_id text,
  report_type text NOT NULL DEFAULT 'vendor'
    CHECK (report_type IN ('vendor', 'support')),
  reason text NOT NULL CHECK (char_length(reason) BETWEEN 1 AND 80),
  details text CHECK (details IS NULL OR char_length(details) <= 2000),
  evidence_paths text[] NOT NULL DEFAULT '{}',
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'reviewing', 'resolved', 'dismissed')),
  reviewed_by text,
  reviewed_at timestamptz,
  admin_notes text CHECK (admin_notes IS NULL OR char_length(admin_notes) <= 2000),
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Repair a partially-created table too, and recreate its text-ID foreign keys.
ALTER TABLE public.vendor_complaints
  ADD COLUMN IF NOT EXISTS reporter_user_id text,
  ADD COLUMN IF NOT EXISTS stall_holder_id text,
  ADD COLUMN IF NOT EXISTS report_type text NOT NULL DEFAULT 'vendor',
  ADD COLUMN IF NOT EXISTS reason text,
  ADD COLUMN IF NOT EXISTS details text,
  ADD COLUMN IF NOT EXISTS evidence_paths text[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'open',
  ADD COLUMN IF NOT EXISTS reviewed_by text,
  ADD COLUMN IF NOT EXISTS reviewed_at timestamptz,
  ADD COLUMN IF NOT EXISTS admin_notes text,
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();

ALTER TABLE public.vendor_complaints
  DROP CONSTRAINT IF EXISTS vendor_complaints_reporter_user_id_fkey,
  DROP CONSTRAINT IF EXISTS vendor_complaints_stall_holder_id_fkey,
  DROP CONSTRAINT IF EXISTS vendor_complaints_reviewed_by_fkey,
  DROP CONSTRAINT IF EXISTS vendor_complaints_report_type_check,
  DROP CONSTRAINT IF EXISTS vendor_complaints_reason_check,
  DROP CONSTRAINT IF EXISTS vendor_complaints_details_check,
  DROP CONSTRAINT IF EXISTS vendor_complaints_status_check,
  DROP CONSTRAINT IF EXISTS vendor_complaints_admin_notes_check;

ALTER TABLE public.vendor_complaints
  ALTER COLUMN reporter_user_id TYPE text USING reporter_user_id::text,
  ALTER COLUMN stall_holder_id TYPE text USING stall_holder_id::text,
  ALTER COLUMN reviewed_by TYPE text USING reviewed_by::text;

ALTER TABLE public.vendor_complaints
  ALTER COLUMN reporter_user_id SET NOT NULL,
  ALTER COLUMN stall_holder_id DROP NOT NULL,
  ALTER COLUMN reason SET NOT NULL,
  ALTER COLUMN status SET DEFAULT 'open',
  ALTER COLUMN status SET NOT NULL,
  ALTER COLUMN created_at SET DEFAULT now(),
  ALTER COLUMN created_at SET NOT NULL,
  ADD CONSTRAINT vendor_complaints_reporter_user_id_fkey
    FOREIGN KEY (reporter_user_id) REFERENCES public.users(user_id) ON DELETE CASCADE,
  ADD CONSTRAINT vendor_complaints_stall_holder_id_fkey
    FOREIGN KEY (stall_holder_id) REFERENCES public.stall_holders(stall_holder_id) ON DELETE SET NULL,
  ADD CONSTRAINT vendor_complaints_reviewed_by_fkey
    FOREIGN KEY (reviewed_by) REFERENCES public.admins(admin_id),
  ADD CONSTRAINT vendor_complaints_report_type_check
    CHECK (report_type IN ('vendor', 'support')),
  ADD CONSTRAINT vendor_complaints_reason_check
    CHECK (char_length(reason) BETWEEN 1 AND 80),
  ADD CONSTRAINT vendor_complaints_details_check
    CHECK (details IS NULL OR char_length(details) <= 2000),
  ADD CONSTRAINT vendor_complaints_status_check
    CHECK (status IN ('open', 'reviewing', 'resolved', 'dismissed')),
  ADD CONSTRAINT vendor_complaints_admin_notes_check
    CHECK (admin_notes IS NULL OR char_length(admin_notes) <= 2000);

CREATE INDEX IF NOT EXISTS vendor_complaints_created_at_idx
  ON public.vendor_complaints(created_at DESC);
CREATE INDEX IF NOT EXISTS vendor_complaints_status_idx
  ON public.vendor_complaints(status, created_at DESC);

ALTER TABLE public.vendor_complaints ENABLE ROW LEVEL SECURITY;
GRANT ALL ON public.vendor_complaints TO service_role;

ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE public.notifications ADD CONSTRAINT notifications_type_check CHECK (
  type IN ('order_update', 'flash_sale', 'kyc_update', 'new_order', 'system_announcement', 'complaint', 'account_action')
);

ALTER TABLE public.admin_activity_logs DROP CONSTRAINT IF EXISTS admin_activity_logs_action_type_check;
ALTER TABLE public.admin_activity_logs ADD CONSTRAINT admin_activity_logs_action_type_check CHECK (
  action_type IN (
    'approved_kyc', 'rejected_kyc', 'blocked_user', 'unblocked_user',
    'exported_report', 'reviewed_complaint', 'warned_user', 'suspended_vendor'
  )
);

CREATE OR REPLACE FUNCTION public.notify_admin_of_vendor_complaint()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  stall_name_value text;
BEGIN
  SELECT stall_name INTO stall_name_value
  FROM public.stall_holders
  WHERE stall_holder_id = NEW.stall_holder_id;

  INSERT INTO public.notifications(user_id, title, body, type, reference_id)
  SELECT u.user_id,
         CASE WHEN NEW.report_type = 'support' THEN 'New support report' ELSE 'New vendor complaint' END,
         CASE WHEN NEW.report_type = 'support'
           THEN 'A user submitted a Help & Support report about ' || NEW.reason || '. Review it in the admin portal.'
           ELSE 'A customer reported ' || coalesce(stall_name_value, 'a vendor') || '. Review it in the admin portal.'
         END,
         'complaint',
         NEW.complaint_id
  FROM public.users u
  WHERE u.role = 'admin';

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS vendor_complaint_notify_admin ON public.vendor_complaints;
CREATE TRIGGER vendor_complaint_notify_admin
AFTER INSERT ON public.vendor_complaints
FOR EACH ROW EXECUTE FUNCTION public.notify_admin_of_vendor_complaint();

CREATE OR REPLACE FUNCTION public.broadcast_vendor_complaint_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, realtime
AS $$
BEGIN
  PERFORM realtime.send(
    jsonb_build_object('table', 'vendor_complaints'),
    'complaint_changed',
    'admin-complaints',
    false
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS vendor_complaint_broadcast_change ON public.vendor_complaints;
CREATE TRIGGER vendor_complaint_broadcast_change
AFTER INSERT OR UPDATE ON public.vendor_complaints
FOR EACH ROW EXECUTE FUNCTION public.broadcast_vendor_complaint_change();

NOTIFY pgrst, 'reload schema';

-- Private evidence photos; uploads and signed reads are mediated by Edge Functions.
INSERT INTO storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
VALUES ('report-evidence', 'report-evidence', false, 5242880,
        ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO UPDATE SET
  public = false,
  file_size_limit = 5242880,
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp'];
