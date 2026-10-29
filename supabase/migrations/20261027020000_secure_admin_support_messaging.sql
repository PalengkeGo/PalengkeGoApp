BEGIN;

CREATE TABLE IF NOT EXISTS public.support_conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id text NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,
  user_role text NOT NULL CHECK (user_role IN ('customer', 'vendor')),
  subject text NOT NULL CHECK (length(btrim(subject)) BETWEEN 1 AND 120),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed')),
  last_message text NOT NULL DEFAULT '',
  last_message_at timestamptz NOT NULL DEFAULT now(),
  user_unread_count integer NOT NULL DEFAULT 0 CHECK (user_unread_count >= 0),
  admin_unread_count integer NOT NULL DEFAULT 0 CHECK (admin_unread_count >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS support_conversations_user_recent_idx
  ON public.support_conversations(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS support_conversations_admin_recent_idx
  ON public.support_conversations(status, updated_at DESC);

CREATE TABLE IF NOT EXISTS public.support_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL REFERENCES public.support_conversations(id) ON DELETE CASCADE,
  sender_user_id text NOT NULL REFERENCES public.users(user_id),
  sender_role text NOT NULL CHECK (sender_role IN ('customer', 'vendor', 'admin')),
  body text NOT NULL CHECK (length(body) BETWEEN 1 AND 4000 AND length(btrim(body)) > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  read_at timestamptz
);

CREATE INDEX IF NOT EXISTS support_messages_conversation_recent_idx
  ON public.support_messages(conversation_id, created_at ASC);

ALTER TABLE public.support_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_messages ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.support_conversations, public.support_messages
  FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.support_conversations, public.support_messages TO service_role;

CREATE OR REPLACE FUNCTION public.support_start_conversation(
  p_user_id text, p_user_role text, p_subject text, p_body text
) RETURNS public.support_conversations
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_conversation public.support_conversations;
BEGIN
  IF p_user_role NOT IN ('customer', 'vendor') OR
     length(btrim(p_subject)) NOT BETWEEN 1 AND 120 OR
     length(p_body) NOT BETWEEN 1 AND 4000 OR length(btrim(p_body)) = 0 THEN
    RAISE EXCEPTION 'Invalid support conversation' USING ERRCODE = '22023';
  END IF;
  INSERT INTO public.support_conversations(user_id, user_role, subject, last_message, last_message_at)
    VALUES(p_user_id, p_user_role, btrim(p_subject), btrim(p_body), clock_timestamp())
    RETURNING * INTO v_conversation;
  INSERT INTO public.support_messages(conversation_id, sender_user_id, sender_role, body)
    VALUES(v_conversation.id, p_user_id, p_user_role, btrim(p_body));
  UPDATE public.support_conversations SET admin_unread_count = 1
    WHERE id = v_conversation.id RETURNING * INTO v_conversation;
  RETURN v_conversation;
END
$$;

CREATE OR REPLACE FUNCTION public.support_send_message(
  p_conversation_id uuid, p_sender_user_id text, p_sender_role text, p_body text
) RETURNS public.support_messages
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_conversation public.support_conversations;
  v_message public.support_messages;
BEGIN
  IF p_sender_role NOT IN ('customer', 'vendor', 'admin') OR
     length(p_body) NOT BETWEEN 1 AND 4000 OR length(btrim(p_body)) = 0 THEN
    RAISE EXCEPTION 'Invalid support message' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO v_conversation FROM public.support_conversations
    WHERE id = p_conversation_id FOR UPDATE;
  IF v_conversation.id IS NULL OR v_conversation.status <> 'open' OR
     (p_sender_role = 'admin' AND NOT EXISTS (
       SELECT 1 FROM public.admins WHERE user_id = p_sender_user_id
     )) OR
     (p_sender_role <> 'admin' AND
       (v_conversation.user_id <> p_sender_user_id OR v_conversation.user_role <> p_sender_role)) THEN
    RAISE EXCEPTION 'Support conversation access denied' USING ERRCODE = '42501';
  END IF;
  INSERT INTO public.support_messages(conversation_id, sender_user_id, sender_role, body)
    VALUES(p_conversation_id, p_sender_user_id, p_sender_role, btrim(p_body))
    RETURNING * INTO v_message;
  UPDATE public.support_conversations SET
    last_message = btrim(p_body),
    last_message_at = v_message.created_at,
    updated_at = v_message.created_at,
    user_unread_count = user_unread_count + CASE WHEN p_sender_role = 'admin' THEN 1 ELSE 0 END,
    admin_unread_count = admin_unread_count + CASE WHEN p_sender_role <> 'admin' THEN 1 ELSE 0 END
    WHERE id = p_conversation_id;
  RETURN v_message;
END
$$;

CREATE OR REPLACE FUNCTION public.support_mark_read(
  p_conversation_id uuid, p_reader_user_id text, p_reader_role text
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_conversation public.support_conversations;
BEGIN
  SELECT * INTO v_conversation FROM public.support_conversations
    WHERE id = p_conversation_id FOR UPDATE;
  IF v_conversation.id IS NULL OR p_reader_role NOT IN ('customer', 'vendor', 'admin') OR
     (p_reader_role = 'admin' AND NOT EXISTS (
       SELECT 1 FROM public.admins WHERE user_id = p_reader_user_id
     )) OR
     (p_reader_role <> 'admin' AND
       (v_conversation.user_id <> p_reader_user_id OR v_conversation.user_role <> p_reader_role)) THEN
    RAISE EXCEPTION 'Support conversation access denied' USING ERRCODE = '42501';
  END IF;
  UPDATE public.support_messages SET read_at = clock_timestamp()
    WHERE conversation_id = p_conversation_id AND sender_role <> p_reader_role AND read_at IS NULL;
  UPDATE public.support_conversations SET
    user_unread_count = CASE WHEN p_reader_role = 'admin' THEN user_unread_count ELSE 0 END,
    admin_unread_count = CASE WHEN p_reader_role = 'admin' THEN 0 ELSE admin_unread_count END
    WHERE id = p_conversation_id;
END
$$;

REVOKE ALL ON FUNCTION public.support_start_conversation(text,text,text,text),
  public.support_send_message(uuid,text,text,text), public.support_mark_read(uuid,text,text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.support_start_conversation(text,text,text,text),
  public.support_send_message(uuid,text,text,text), public.support_mark_read(uuid,text,text)
  TO service_role;

ALTER TABLE public.admin_activity_logs
  DROP CONSTRAINT IF EXISTS admin_activity_logs_action_type_check;
ALTER TABLE public.admin_activity_logs
  ADD CONSTRAINT admin_activity_logs_action_type_check CHECK (
    action_type IN (
      'approved_kyc', 'rejected_kyc', 'blocked_user', 'unblocked_user',
      'exported_report', 'reviewed_complaint', 'warned_user',
      'suspended_vendor', 'suspended_user', 'lifted_suspension',
      'updated_account_notes', 'resolved_report', 'admin_logged_in',
      'admin_logged_out', 'updated_admin_profile', 'published_announcement',
      'updated_announcement', 'deleted_announcement', 'support_message_sent',
      'support_conversation_closed'
    )
  );
ALTER TABLE public.admin_activity_logs
  DROP CONSTRAINT IF EXISTS admin_activity_logs_target_type_check;
ALTER TABLE public.admin_activity_logs
  ADD CONSTRAINT admin_activity_logs_target_type_check CHECK (
    target_type IS NULL OR target_type IN (
      'user', 'stallholder', 'kyc', 'report', 'authentication',
      'announcement', 'product', 'system', 'support_conversation'
    )
  );

COMMIT;
