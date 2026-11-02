BEGIN;

CREATE OR REPLACE FUNCTION public.notify_admin_of_kyc_submission()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_stall_name text;
BEGIN
  SELECT s.stall_name INTO v_stall_name
  FROM public.stall_holders s
  WHERE s.stall_holder_id = NEW.stall_holder_id;

  INSERT INTO public.notifications(user_id, title, body, type, reference_id)
  SELECT u.user_id,
         'New stall holder application',
         'A new application was submitted for ' || coalesce(v_stall_name, 'a stall') || '. Review it in the admin portal.',
         'kyc_update',
         NEW.kyc_id::text
  FROM public.users u
  WHERE u.role = 'admin';

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.notify_admin_of_kyc_submission() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_notify_admin_of_kyc_submission ON public.kyc_submissions;
CREATE TRIGGER trg_notify_admin_of_kyc_submission
AFTER INSERT ON public.kyc_submissions
FOR EACH ROW EXECUTE FUNCTION public.notify_admin_of_kyc_submission();

COMMIT;
