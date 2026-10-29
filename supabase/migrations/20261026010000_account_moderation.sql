BEGIN;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS suspended_from timestamptz;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS suspended_until timestamptz;

-- Internal notes and moderation records are accessible only through the admin API.
CREATE TABLE IF NOT EXISTS public.account_admin_notes (
  user_id text PRIMARY KEY REFERENCES public.users(user_id),
  notes text NOT NULL DEFAULT '' CHECK (length(notes) <= 500)
);
CREATE TABLE IF NOT EXISTS public.account_suspensions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id text NOT NULL REFERENCES public.users(user_id),
  admin_id text NOT NULL REFERENCES public.admins(admin_id),
  reason text NOT NULL CHECK (length(trim(reason)) BETWEEN 1 AND 120),
  note text NOT NULL DEFAULT '' CHECK (length(note) <= 300),
  starts_at timestamptz NOT NULL,
  ends_at timestamptz NOT NULL CHECK (ends_at > starts_at),
  notify_user boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  lifted_at timestamptz
);
ALTER TABLE public.account_admin_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.account_suspensions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.account_admin_notes, public.account_suspensions FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.account_admin_notes, public.account_suspensions TO service_role;

ALTER TABLE public.admin_activity_logs DROP CONSTRAINT IF EXISTS admin_activity_logs_action_type_check;
ALTER TABLE public.admin_activity_logs ADD CONSTRAINT admin_activity_logs_action_type_check CHECK (
  action_type IN ('approved_kyc','rejected_kyc','blocked_user','unblocked_user',
    'exported_report','reviewed_complaint','warned_user','suspended_vendor',
    'suspended_user','lifted_suspension','updated_account_notes','resolved_report')
);

CREATE OR REPLACE FUNCTION public.moderate_account(
  p_actor text, p_user text, p_action text, p_notes text DEFAULT NULL,
  p_reason text DEFAULT '', p_start timestamptz DEFAULT NULL,
  p_end timestamptz DEFAULT NULL, p_notify boolean DEFAULT true,
  p_suspension uuid DEFAULT NULL
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_admin text; v_user public.users; v_action text; v_title text; v_body text;
BEGIN
  SELECT a.admin_id INTO v_admin FROM public.admins a JOIN public.users u ON u.user_id=a.user_id
    WHERE a.user_id=p_actor AND u.role='admin' AND NOT coalesce(u.is_blocked,false);
  IF v_admin IS NULL OR p_actor=p_user THEN RAISE EXCEPTION 'Account action denied' USING ERRCODE='42501'; END IF;
  SELECT * INTO v_user FROM public.users WHERE user_id=p_user AND role <> 'admin' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Account not found' USING ERRCODE='22023'; END IF;
  IF p_notes IS NOT NULL AND p_action <> 'suspend' THEN
    INSERT INTO public.account_admin_notes(user_id,notes) VALUES(p_user,p_notes)
      ON CONFLICT(user_id) DO UPDATE SET notes=excluded.notes;
  END IF;
  IF p_action='notes' THEN
    v_action := 'updated_account_notes';
  ELSIF p_action IN ('block','unblock') THEN
    UPDATE public.users SET is_blocked=(p_action='block'), updated_at=now() WHERE user_id=p_user;
    IF p_action='block' THEN
      UPDATE public.account_suspensions SET lifted_at=now() WHERE user_id=p_user AND lifted_at IS NULL;
      UPDATE public.users SET suspended_from=NULL,suspended_until=NULL WHERE user_id=p_user;
    END IF;
    v_action := CASE WHEN p_action='block' THEN 'blocked_user' ELSE 'unblocked_user' END;
    v_title := CASE WHEN p_action='block' THEN 'Account blocked' ELSE 'Account restored' END;
    v_body := CASE WHEN p_action='block' THEN 'An administrator blocked your account. Contact support for assistance.' ELSE 'An administrator restored access to your account.' END;
  ELSIF p_action='suspend' THEN
    IF coalesce(v_user.is_blocked,false) OR p_start IS NULL OR p_end IS NULL OR p_end<=p_start OR p_end<=now()
       OR length(trim(p_reason)) NOT BETWEEN 1 AND 120 THEN
      RAISE EXCEPTION 'Invalid suspension dates, reason, or account status' USING ERRCODE='22023';
    END IF;
    IF EXISTS(SELECT 1 FROM public.account_suspensions WHERE user_id=p_user AND lifted_at IS NULL AND ends_at>now()) THEN
      RAISE EXCEPTION 'Account already has an active or scheduled suspension' USING ERRCODE='22023';
    END IF;
    INSERT INTO public.account_suspensions(user_id,admin_id,reason,note,starts_at,ends_at,notify_user)
      VALUES(p_user,v_admin,trim(p_reason),coalesce(p_notes,''),p_start,p_end,p_notify);
    UPDATE public.users SET suspended_from=p_start,suspended_until=p_end,updated_at=now() WHERE user_id=p_user;
    v_action := 'suspended_user'; v_title := 'Account suspension';
    v_body := p_reason || '. From ' || to_char(p_start AT TIME ZONE 'Asia/Manila','Mon DD, YYYY HH12:MI AM')
      || ' until ' || to_char(p_end AT TIME ZONE 'Asia/Manila','Mon DD, YYYY HH12:MI AM') || ' (Philippine time). Contact support for assistance.';
  ELSIF p_action='lift' THEN
    UPDATE public.account_suspensions SET lifted_at=now() WHERE id=p_suspension AND user_id=p_user AND lifted_at IS NULL AND ends_at>now();
    IF NOT FOUND THEN RAISE EXCEPTION 'Suspension is no longer active' USING ERRCODE='22023'; END IF;
    UPDATE public.users SET suspended_from=NULL,suspended_until=NULL,updated_at=now() WHERE user_id=p_user;
    v_action := 'lifted_suspension'; v_title := 'Suspension lifted'; v_body := 'An administrator lifted your account suspension.';
  ELSE RAISE EXCEPTION 'Invalid account action' USING ERRCODE='22023';
  END IF;
  INSERT INTO public.admin_activity_logs(admin_id,action_type,target_id,target_type,remarks)
    VALUES(v_admin,v_action,p_user,'user',CASE WHEN p_action='suspend' THEN p_reason ELSE v_title END);
  IF p_notify AND v_title IS NOT NULL THEN
    INSERT INTO public.notifications(user_id,title,body,type) VALUES(p_user,v_title,v_body,'system_announcement');
  END IF;
END $$;
REVOKE ALL ON FUNCTION public.moderate_account(text,text,text,text,text,timestamptz,timestamptz,boolean,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.moderate_account(text,text,text,text,text,timestamptz,timestamptz,boolean,uuid) TO service_role;

-- Existing profile-update policies must not let clients undo moderation.
CREATE OR REPLACE FUNCTION public.protect_account_moderation() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF current_user IN ('anon','authenticated') AND
    (NEW.is_blocked IS DISTINCT FROM OLD.is_blocked OR NEW.suspended_from IS DISTINCT FROM OLD.suspended_from
     OR NEW.suspended_until IS DISTINCT FROM OLD.suspended_until) THEN
    RAISE EXCEPTION 'Only administrators can change account access' USING ERRCODE='42501';
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS protect_account_moderation ON public.users;
CREATE TRIGGER protect_account_moderation BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.protect_account_moderation();

-- Enforce restrictions for both parties even on legacy direct order inserts.
CREATE OR REPLACE FUNCTION public.check_order_account_access() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.users u WHERE
      (u.user_id IN (SELECT c.user_id FROM public.customers c WHERE c.customer_id=NEW.customer_id)
       OR u.user_id=NEW.customer_id
       OR u.user_id IN (SELECT s.user_id FROM public.stall_holders s WHERE s.stall_holder_id=NEW.stall_holder_id))
      AND (coalesce(u.is_blocked,false) OR coalesce(u.suspended_from<=now() AND u.suspended_until>now(),false))
  ) THEN
    RAISE EXCEPTION 'Customer or stall holder account is restricted' USING ERRCODE='42501';
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS check_order_account_access ON public.orders;
CREATE TRIGGER check_order_account_access BEFORE INSERT ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.check_order_account_access();

CREATE OR REPLACE FUNCTION public.chat_uid() RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT u.user_id FROM public.users u WHERE u.user_id=auth.jwt()->>'sub'
    AND auth.jwt()->>'iss'='https://securetoken.google.com/palengkegodb'
    AND auth.jwt()->>'aud'='palengkegodb' AND NOT coalesce(u.is_blocked,false)
    AND NOT coalesce(u.suspended_from<=now() AND u.suspended_until>now(),false)
$$;
COMMIT;
