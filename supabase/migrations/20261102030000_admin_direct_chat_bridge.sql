BEGIN;

CREATE OR REPLACE FUNCTION public.support_actor(p_uid text, p_role text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.user_id = p_uid
      AND NOT coalesce(u.is_blocked, false)
      AND NOT (coalesce(u.suspended_from <= now(), false) AND coalesce(u.suspended_until > now(), false))
      AND (
        (p_role = 'admin' AND u.role = 'admin' AND EXISTS (
          SELECT 1 FROM public.admins ca WHERE ca.user_id = u.user_id
        ))
        OR
        (p_role = 'vendor' AND u.role IN ('vendor', 'stallholder') AND EXISTS (
          SELECT 1 FROM public.stall_holders s
          WHERE s.user_id = u.user_id
            AND NOT coalesce(s.is_blocked, false)
            AND (coalesce(s.is_kyc_approved, false) OR s.kyc_status = 'approved')
        ))
      )
  )
$$;
REVOKE ALL ON FUNCTION public.support_actor(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.support_actor(text, text) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_direct_chat_send(
  p_conversation_id text,
  p_actor text,
  p_body text,
  p_attachment_url text DEFAULT NULL
) RETURNS public.messages
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_conversation public.conversations;
  v_message public.messages;
BEGIN
  SELECT * INTO v_conversation FROM public.conversations
  WHERE id = p_conversation_id AND customer_uid = p_actor
  FOR UPDATE;

  IF v_conversation.id IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.admins a WHERE a.user_id = p_actor
  ) THEN
    RAISE EXCEPTION 'Admin conversation access denied' USING ERRCODE = '42501';
  END IF;
  IF p_body IS NULL OR length(p_body) > 10000 OR
     (length(btrim(p_body)) = 0 AND p_attachment_url IS NULL) OR
     (p_attachment_url IS NOT NULL AND NOT EXISTS (
       SELECT 1 FROM storage.objects o
       WHERE o.bucket_id = 'chat-attachments'
         AND 'chat-attachments/' || o.name = p_attachment_url
         AND split_part(o.name, '/', 1) = p_conversation_id
         AND split_part(o.name, '/', 2) = p_actor
     )) THEN
    RAISE EXCEPTION 'Invalid admin chat message' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.messages(
    conversation_id, sender_id, sender_name, sender_role, text,
    timestamp, is_read, attachment_url, attachment_type
  ) VALUES (
    p_conversation_id, p_actor, 'PalengkeGo Admin', 'admin', btrim(p_body),
    clock_timestamp(), false, p_attachment_url,
    CASE WHEN p_attachment_url IS NULL THEN NULL ELSE 'image' END
  ) RETURNING * INTO v_message;

  UPDATE public.conversations SET
    last_message_text = CASE WHEN btrim(p_body) = '' THEN '📷 Photo' ELSE btrim(p_body) END,
    last_message_timestamp = v_message.timestamp,
    last_message_sender_id = p_actor,
    updated_at = v_message.timestamp,
    vendor_unread_count = coalesce(vendor_unread_count, 0) + 1
  WHERE id = p_conversation_id;

  RETURN v_message;
END
$$;

CREATE OR REPLACE FUNCTION public.admin_direct_chat_mark_read(
  p_conversation_id text,
  p_actor text
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_conversation public.conversations;
BEGIN
  SELECT * INTO v_conversation FROM public.conversations
  WHERE id = p_conversation_id AND customer_uid = p_actor
  FOR UPDATE;
  IF v_conversation.id IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.admins a WHERE a.user_id = p_actor
  ) THEN
    RAISE EXCEPTION 'Admin conversation access denied' USING ERRCODE = '42501';
  END IF;

  UPDATE public.messages SET is_read = true, read_at = clock_timestamp()
  WHERE conversation_id = p_conversation_id AND sender_role <> 'admin' AND NOT is_read;
  UPDATE public.conversations SET customer_unread_count = 0
  WHERE id = p_conversation_id;
END
$$;

REVOKE ALL ON FUNCTION public.admin_direct_chat_send(text, text, text, text),
  public.admin_direct_chat_mark_read(text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_direct_chat_send(text, text, text, text),
  public.admin_direct_chat_mark_read(text, text) TO service_role;

COMMIT;
