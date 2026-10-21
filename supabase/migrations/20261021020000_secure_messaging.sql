-- Firebase JWTs are verified by Supabase Third-party Auth before these checks.
-- Keep writes inside RPC transactions so message/read-receipt updates share
-- the same per-conversation row lock. Existing conversations/messages survive.
BEGIN;

DROP POLICY IF EXISTS "Allow manage conversations" ON public.conversations;
DROP POLICY IF EXISTS "Allow manage messages" ON public.messages;
REVOKE ALL ON public.conversations, public.messages FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.conversations, public.messages TO authenticated;

CREATE UNIQUE INDEX IF NOT EXISTS conversations_participants_unique
  ON public.conversations (stall_id, customer_uid);

CREATE OR REPLACE FUNCTION public.chat_uid() RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT u.user_id FROM public.users u
  WHERE u.user_id = auth.jwt()->>'sub'
    AND auth.jwt()->>'iss' = 'https://securetoken.google.com/palengkegodb'
    AND auth.jwt()->>'aud' = 'palengkegodb'
    AND NOT coalesce(u.is_blocked, false)
$$;

CREATE OR REPLACE FUNCTION public.chat_role(p_conversation_id text) RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT CASE WHEN c.customer_uid = public.chat_uid() THEN 'customer'
              WHEN s.user_id = public.chat_uid() THEN 'vendor' END
  FROM public.conversations c
  JOIN public.stall_holders s ON s.stall_holder_id = c.stall_id
  WHERE c.id = p_conversation_id AND NOT coalesce(s.is_blocked, false)
$$;

-- chat-auth provisions the authenticated claim on verified Firebase users.
-- The public API key alone never grants chat access.
CREATE POLICY chat_participant_conversations ON public.conversations
  FOR SELECT TO authenticated USING (public.chat_role(id) IS NOT NULL);
CREATE POLICY chat_participant_messages ON public.messages
  FOR SELECT TO authenticated USING (public.chat_role(conversation_id) IS NOT NULL);

CREATE OR REPLACE FUNCTION public.chat_get_or_create(
  p_stall_id text, p_customer_uid text, p_inquiry_type text DEFAULT 'general',
  p_related_order_id text DEFAULT NULL
) RETURNS public.conversations
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_uid text := public.chat_uid();
  v_stall public.stall_holders;
  v_customer public.users;
  v_conversation public.conversations;
BEGIN
  SELECT * INTO v_stall FROM public.stall_holders
    WHERE stall_holder_id = p_stall_id AND NOT coalesce(is_blocked, false);
  SELECT * INTO v_customer FROM public.users
    WHERE user_id = p_customer_uid AND role = 'customer' AND NOT coalesce(is_blocked, false);
  IF v_uid IS NULL OR v_stall.stall_holder_id IS NULL OR v_customer.user_id IS NULL
     OR (v_uid <> p_customer_uid AND v_uid <> v_stall.user_id) THEN
    RAISE EXCEPTION 'Chat access denied' USING ERRCODE = '42501';
  END IF;
  IF p_inquiry_type IS NULL OR length(p_inquiry_type) > 50 THEN
    RAISE EXCEPTION 'Invalid inquiry type' USING ERRCODE = '22023';
  END IF;
  IF p_related_order_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.orders o WHERE o.order_id = p_related_order_id
    AND o.stall_holder_id = p_stall_id AND (o.customer_id = p_customer_uid OR
      o.customer_id IN (SELECT customer_id FROM public.customers WHERE user_id = p_customer_uid))
  ) THEN
    RAISE EXCEPTION 'Invalid related order' USING ERRCODE = '42501';
  END IF;
  INSERT INTO public.conversations(stall_id, stall_name, customer_uid, customer_name,
    stall_avatar, customer_avatar, inquiry_type, related_order_id)
  VALUES(p_stall_id, v_stall.stall_name, p_customer_uid, v_customer.full_name,
    coalesce(v_stall.thumbnail_url, v_stall.banner_image_url), v_customer.profile_photo,
    p_inquiry_type, p_related_order_id)
  ON CONFLICT (stall_id, customer_uid) DO NOTHING;
  SELECT * INTO v_conversation FROM public.conversations
    WHERE stall_id = p_stall_id AND customer_uid = p_customer_uid;
  RETURN v_conversation;
END
$$;

CREATE OR REPLACE FUNCTION public.chat_send_message(
  p_conversation_id text, p_text text, p_attachment_url text DEFAULT NULL,
  p_attachment_type text DEFAULT NULL
) RETURNS public.messages
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_role text;
  v_conversation public.conversations;
  v_message public.messages;
  v_sender_id text;
  v_sender_name text;
BEGIN
  -- Send and mark-read acquire this lock before touching messages or counters.
  SELECT * INTO v_conversation FROM public.conversations
    WHERE id = p_conversation_id FOR UPDATE;
  v_role := public.chat_role(p_conversation_id);
  IF v_role IS NULL THEN
    RAISE EXCEPTION 'Chat access denied' USING ERRCODE = '42501';
  END IF;
  IF p_text IS NULL OR length(p_text) > 10000 OR
    (btrim(p_text) = '' AND nullif(p_attachment_url, '') IS NULL) OR
    (p_attachment_url IS NOT NULL AND
      (length(p_attachment_url) > 1024 OR NOT EXISTS (
        SELECT 1 FROM storage.objects o WHERE o.bucket_id = 'chat-attachments'
          AND 'chat-attachments/' || o.name = p_attachment_url
          AND split_part(o.name, '/', 1) = p_conversation_id
          AND split_part(o.name, '/', 2) = public.chat_uid()
      ))) OR
    (p_attachment_type IS NOT NULL AND p_attachment_type NOT IN ('image', 'photo')) THEN
    RAISE EXCEPTION 'Invalid message' USING ERRCODE = '22023';
  END IF;
  v_sender_id := CASE WHEN v_role = 'vendor' THEN v_conversation.stall_id ELSE public.chat_uid() END;
  SELECT CASE WHEN v_role = 'vendor' THEN s.stall_name ELSE u.full_name END
    INTO v_sender_name FROM public.users u, public.stall_holders s
    WHERE u.user_id = public.chat_uid() AND s.stall_holder_id = v_conversation.stall_id;
  INSERT INTO public.messages(conversation_id, sender_id, sender_name, sender_role,
    text, timestamp, attachment_url, attachment_type)
  VALUES(p_conversation_id, v_sender_id, v_sender_name, v_role, btrim(p_text),
    clock_timestamp(), p_attachment_url, p_attachment_type) RETURNING * INTO v_message;
  UPDATE public.conversations SET
    last_message_text = CASE WHEN v_message.text = '' THEN '📷 Photo' ELSE v_message.text END,
    last_message_timestamp = v_message.timestamp,
    last_message_sender_id = v_sender_id, updated_at = v_message.timestamp,
    customer_unread_count = coalesce(customer_unread_count, 0) + CASE WHEN v_role = 'vendor' THEN 1 ELSE 0 END,
    vendor_unread_count = coalesce(vendor_unread_count, 0) + CASE WHEN v_role = 'customer' THEN 1 ELSE 0 END
  WHERE id = p_conversation_id;
  RETURN v_message;
END
$$;

CREATE OR REPLACE FUNCTION public.chat_mark_read(p_conversation_id text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_role text;
BEGIN
  PERFORM 1 FROM public.conversations WHERE id = p_conversation_id FOR UPDATE;
  v_role := public.chat_role(p_conversation_id);
  IF v_role IS NULL THEN
    RAISE EXCEPTION 'Chat access denied' USING ERRCODE = '42501';
  END IF;
  UPDATE public.messages SET is_read = true, read_at = clock_timestamp()
    WHERE conversation_id = p_conversation_id AND sender_role <> v_role AND NOT is_read;
  UPDATE public.conversations SET
    customer_unread_count = CASE WHEN v_role = 'customer' THEN 0 ELSE customer_unread_count END,
    vendor_unread_count = CASE WHEN v_role = 'vendor' THEN 0 ELSE vendor_unread_count END
    WHERE id = p_conversation_id;
END
$$;

-- Repair previously lost counters from messages rather than trusting client totals.
UPDATE public.conversations c SET
  customer_unread_count = (SELECT count(*) FROM public.messages m
    WHERE m.conversation_id = c.id AND m.sender_role = 'vendor' AND NOT m.is_read),
  vendor_unread_count = (SELECT count(*) FROM public.messages m
    WHERE m.conversation_id = c.id AND m.sender_role = 'customer' AND NOT m.is_read);

REVOKE ALL ON FUNCTION public.chat_uid(), public.chat_role(text),
  public.chat_get_or_create(text,text,text,text), public.chat_send_message(text,text,text,text),
  public.chat_mark_read(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.chat_uid(), public.chat_role(text),
  public.chat_get_or_create(text,text,text,text), public.chat_send_message(text,text,text,text),
  public.chat_mark_read(text) TO authenticated;

-- Typing broadcasts must use private channels with the same participant check.
CREATE POLICY chat_receive_typing ON realtime.messages FOR SELECT TO authenticated
  USING (extension = 'broadcast' AND public.chat_role(
    CASE WHEN realtime.topic() LIKE 'chat-room-%' THEN substr(realtime.topic(), 11) END
  ) IS NOT NULL);
CREATE POLICY chat_send_typing ON realtime.messages FOR INSERT TO authenticated
  WITH CHECK (extension = 'broadcast' AND public.chat_role(
    CASE WHEN realtime.topic() LIKE 'chat-room-%' THEN substr(realtime.topic(), 11) END
  ) IS NOT NULL);

INSERT INTO storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
VALUES ('chat-attachments', 'chat-attachments', false, 10485760,
  ARRAY['image/jpeg','image/png','image/webp'])
ON CONFLICT (id) DO UPDATE SET public = false, file_size_limit = 10485760,
  allowed_mime_types = ARRAY['image/jpeg','image/png','image/webp'];
CREATE POLICY chat_read_attachment ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'chat-attachments' AND
    public.chat_role(split_part(name, '/', 1)) IS NOT NULL);
CREATE POLICY chat_upload_attachment ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'chat-attachments' AND
    public.chat_role(split_part(name, '/', 1)) IS NOT NULL AND
    split_part(name, '/', 2) = public.chat_uid());
COMMIT;
