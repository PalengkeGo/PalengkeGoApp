BEGIN;

-- No customer chat data is deleted or migrated into the admin support inbox.
ALTER TABLE public.support_messages ADD COLUMN IF NOT EXISTS attachment_path text;
ALTER TABLE public.support_messages DROP CONSTRAINT IF EXISTS support_messages_body_check;
ALTER TABLE public.support_messages ADD CONSTRAINT support_messages_body_check CHECK (
  length(body) <= 4000 AND (length(btrim(body)) > 0 OR attachment_path IS NOT NULL)
);
CREATE INDEX IF NOT EXISTS support_messages_cursor_idx
  ON public.support_messages(conversation_id, created_at DESC, id DESC);

CREATE OR REPLACE FUNCTION public.support_actor(p_uid text, p_role text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users u WHERE u.user_id = p_uid
      AND NOT coalesce(u.is_blocked, false)
      AND NOT (coalesce(u.suspended_from <= now(), false) AND coalesce(u.suspended_until > now(), false))
      AND ((p_role = 'admin' AND u.role = 'admin' AND EXISTS (
        SELECT 1 FROM public.admins ca WHERE ca.user_id = u.user_id))
      OR (p_role = 'vendor' AND u.role IN ('vendor', 'stallholder') AND EXISTS (
        SELECT 1 FROM public.stall_holders s WHERE s.user_id = u.user_id
          AND NOT coalesce(s.is_blocked, false)
          AND (coalesce(s.is_kyc_approved, false) OR s.kyc_status = 'approved'))))
  )
$$;

CREATE OR REPLACE FUNCTION public.support_can_read(p_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (SELECT 1 FROM public.support_conversations c
    WHERE c.id = p_id AND c.user_role = 'vendor'
      AND (public.support_actor(public.chat_uid(), 'admin') OR
        (c.user_id = public.chat_uid() AND public.support_actor(public.chat_uid(), 'vendor'))))
$$;
REVOKE ALL ON FUNCTION public.support_actor(text,text), public.support_can_read(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.support_actor(text,text), public.support_can_read(uuid) TO authenticated, service_role;
GRANT SELECT ON public.support_conversations, public.support_messages TO authenticated;
CREATE POLICY support_participant_conversations ON public.support_conversations
  FOR SELECT TO authenticated USING (public.support_can_read(id));
CREATE POLICY support_participant_messages ON public.support_messages
  FOR SELECT TO authenticated USING (public.support_can_read(conversation_id));

INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
VALUES ('support-attachments','support-attachments',false,2097152,ARRAY['image/jpeg','image/png','image/webp','image/gif'])
ON CONFLICT (id) DO UPDATE SET public=false,file_size_limit=2097152,
  allowed_mime_types=EXCLUDED.allowed_mime_types;

CREATE OR REPLACE FUNCTION public.support_start_conversation(
  p_user_id text, p_user_role text, p_subject text, p_body text
) RETURNS public.support_conversations
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_conversation public.support_conversations;
BEGIN
  IF p_user_role IS DISTINCT FROM 'vendor' OR NOT public.support_actor(p_user_id, p_user_role) OR
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
  IF NOT public.support_actor(p_sender_user_id, p_sender_role) OR
     length(p_body) NOT BETWEEN 1 AND 4000 OR length(btrim(p_body)) = 0 THEN
    RAISE EXCEPTION 'Invalid support message' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO v_conversation FROM public.support_conversations
    WHERE id = p_conversation_id FOR UPDATE;
  IF v_conversation.id IS NULL OR v_conversation.user_role <> 'vendor' OR v_conversation.status <> 'open' OR
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
  IF v_conversation.id IS NULL OR v_conversation.user_role <> 'vendor' OR NOT public.support_actor(p_reader_user_id, p_reader_role) OR
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

CREATE OR REPLACE FUNCTION public.support_send_photo(
  p_conversation_id uuid, p_sender_user_id text, p_sender_role text, p_body text, p_attachment_path text
) RETURNS public.support_messages
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_conversation public.support_conversations;
  v_message public.support_messages;
BEGIN
  IF NOT public.support_actor(p_sender_user_id, p_sender_role) OR
     p_body IS NULL OR length(p_body) > 4000 OR p_attachment_path IS NULL OR NOT EXISTS (SELECT 1 FROM storage.objects WHERE bucket_id = 'support-attachments' AND name = p_attachment_path AND split_part(name, '/', 1) = p_conversation_id::text AND split_part(name, '/', 2) = p_sender_user_id) THEN
    RAISE EXCEPTION 'Invalid support message' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO v_conversation FROM public.support_conversations
    WHERE id = p_conversation_id FOR UPDATE;
  IF v_conversation.id IS NULL OR v_conversation.user_role <> 'vendor' OR v_conversation.status <> 'open' OR
     (p_sender_role = 'admin' AND NOT EXISTS (
       SELECT 1 FROM public.admins WHERE user_id = p_sender_user_id
     )) OR
     (p_sender_role <> 'admin' AND
       (v_conversation.user_id <> p_sender_user_id OR v_conversation.user_role <> p_sender_role)) THEN
    RAISE EXCEPTION 'Support conversation access denied' USING ERRCODE = '42501';
  END IF;
  INSERT INTO public.support_messages(conversation_id, sender_user_id, sender_role, body, attachment_path)
    VALUES(p_conversation_id, p_sender_user_id, p_sender_role, btrim(p_body), p_attachment_path)
    RETURNING * INTO v_message;
  UPDATE public.support_conversations SET
    last_message = coalesce(nullif(btrim(p_body), ''), 'Photo'),
    last_message_at = v_message.created_at,
    updated_at = v_message.created_at,
    user_unread_count = user_unread_count + CASE WHEN p_sender_role = 'admin' THEN 1 ELSE 0 END,
    admin_unread_count = admin_unread_count + CASE WHEN p_sender_role <> 'admin' THEN 1 ELSE 0 END
    WHERE id = p_conversation_id;
  RETURN v_message;
END
$$;


REVOKE ALL ON FUNCTION public.support_send_photo(uuid,text,text,text,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.support_send_photo(uuid,text,text,text,text) TO service_role;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename='support_conversations') THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.support_conversations;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename='support_messages') THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.support_messages;
    END IF;
  END IF;
END $$;
COMMIT;
