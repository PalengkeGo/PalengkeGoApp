CREATE TABLE IF NOT EXISTS public.vendor_complaints (
  complaint_id text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  reporter_user_id text NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,
  stall_holder_id text NOT NULL REFERENCES public.stall_holders(stall_holder_id) ON DELETE CASCADE,
  reason text NOT NULL CHECK (char_length(reason) BETWEEN 1 AND 80),
  details text CHECK (details IS NULL OR char_length(details) <= 2000),
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

ALTER TABLE public.vendor_complaints ENABLE ROW LEVEL SECURITY;
GRANT ALL ON public.vendor_complaints TO service_role;

ALTER TABLE public.notifications
  DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_type_check CHECK (
    type IN ('order_update', 'flash_sale', 'kyc_update', 'new_order', 'system_announcement', 'complaint')
  );

ALTER TABLE public.admin_activity_logs
  DROP CONSTRAINT IF EXISTS admin_activity_logs_action_type_check;
ALTER TABLE public.admin_activity_logs
  ADD CONSTRAINT admin_activity_logs_action_type_check CHECK (
    action_type IN (
      'approved_kyc', 'rejected_kyc', 'blocked_user', 'unblocked_user',
      'exported_report', 'reviewed_complaint'
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
         'New vendor complaint',
         'A customer reported ' || coalesce(stall_name_value, 'a vendor') || '. Review it in the admin portal.',
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
