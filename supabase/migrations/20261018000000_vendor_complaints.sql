CREATE TABLE IF NOT EXISTS public.vendor_complaints (
  complaint_id text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  reporter_user_id text NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,
  stall_holder_id text REFERENCES public.stall_holders(stall_holder_id) ON DELETE SET NULL,
  report_type text NOT NULL DEFAULT 'vendor' CHECK (report_type IN ('vendor', 'support')),
  reason text NOT NULL CHECK (char_length(reason) BETWEEN 1 AND 80),
  details text CHECK (details IS NULL OR char_length(details) <= 2000),
  evidence_paths text[] NOT NULL DEFAULT '{}',
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'reviewing', 'resolved', 'dismissed')),
  reviewed_by text REFERENCES public.admins(admin_id),
  reviewed_at timestamptz,
  admin_notes text CHECK (admin_notes IS NULL OR char_length(admin_notes) <= 2000),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS vendor_complaints_created_at_idx
  ON public.vendor_complaints(created_at DESC);
CREATE INDEX IF NOT EXISTS vendor_complaints_status_idx
  ON public.vendor_complaints(status, created_at DESC);

ALTER TABLE public.vendor_complaints
  ADD COLUMN IF NOT EXISTS report_type text NOT NULL DEFAULT 'vendor';

ALTER TABLE public.vendor_complaints
  ADD COLUMN IF NOT EXISTS evidence_paths text[] NOT NULL DEFAULT '{}';

ALTER TABLE public.vendor_complaints
  ALTER COLUMN stall_holder_id DROP NOT NULL,
  DROP CONSTRAINT IF EXISTS vendor_complaints_stall_holder_id_fkey,
  DROP CONSTRAINT IF EXISTS vendor_complaints_report_type_check,
  ADD CONSTRAINT vendor_complaints_stall_holder_id_fkey
    FOREIGN KEY (stall_holder_id) REFERENCES public.stall_holders(stall_holder_id) ON DELETE SET NULL,
  ADD CONSTRAINT vendor_complaints_report_type_check CHECK (report_type IN ('vendor', 'support'));

ALTER TABLE public.vendor_complaints ENABLE ROW LEVEL SECURITY;
GRANT ALL ON public.vendor_complaints TO service_role;

ALTER TABLE public.notifications
  DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_type_check CHECK (
    type IN ('order_update', 'flash_sale', 'kyc_update', 'new_order', 'system_announcement', 'complaint', 'account_action')
  );

ALTER TABLE public.admin_activity_logs
  DROP CONSTRAINT IF EXISTS admin_activity_logs_action_type_check;
ALTER TABLE public.admin_activity_logs
  ADD CONSTRAINT admin_activity_logs_action_type_check CHECK (
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
DECLARE stall_name_value text;
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
