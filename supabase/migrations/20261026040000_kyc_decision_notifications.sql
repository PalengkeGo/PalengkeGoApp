BEGIN;

ALTER TABLE public.notifications
  DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_type_check CHECK (
    type IN ('order_update', 'flash_sale', 'kyc_update', 'new_order',
      'system_announcement', 'complaint', 'account_action')
  );

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'stall_holders'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.stall_holders;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.sync_kyc_review_to_app()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id text;
  v_title text;
  v_body text;
BEGIN
  IF NEW.status IS NOT DISTINCT FROM OLD.status
     OR NEW.status NOT IN ('approved', 'rejected') THEN
    RETURN NEW;
  END IF;

  SELECT s.user_id INTO v_user_id
  FROM public.stall_holders s
  WHERE s.stall_holder_id = NEW.stall_holder_id;
  IF v_user_id IS NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.status = 'approved' THEN
    UPDATE public.stall_holders
    SET is_kyc_approved = true, kyc_status = 'approved'
    WHERE stall_holder_id = NEW.stall_holder_id;
    UPDATE public.users SET role = 'vendor'
    WHERE user_id = v_user_id;
    v_title := 'Application approved';
    v_body := 'MEPO approved your stall holder application. Your vendor access is now active.';
  ELSE
    UPDATE public.stall_holders
    SET is_kyc_approved = false, kyc_status = 'rejected'
    WHERE stall_holder_id = NEW.stall_holder_id;
    v_title := 'Application rejected';
    v_body := 'MEPO rejected your stall holder application.';
    IF coalesce(trim(NEW.rejection_reason), '') <> '' THEN
      v_body := v_body || ' Reason: ' || trim(NEW.rejection_reason);
    END IF;
    v_body := v_body || ' Please review the reason and resubmit your documents.';
  END IF;

  INSERT INTO public.notifications(user_id, title, body, type, reference_id)
  VALUES(v_user_id, v_title, v_body, 'kyc_update', NEW.kyc_id);
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.sync_kyc_review_to_app() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_sync_kyc_review_to_app ON public.kyc_submissions;
CREATE TRIGGER trg_sync_kyc_review_to_app
AFTER UPDATE OF status ON public.kyc_submissions
FOR EACH ROW EXECUTE FUNCTION public.sync_kyc_review_to_app();

COMMIT;
