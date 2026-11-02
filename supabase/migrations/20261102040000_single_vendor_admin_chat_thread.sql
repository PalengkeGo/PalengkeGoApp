BEGIN;

-- Fold existing stallholder support threads into one continuous history per
-- account. Keep every message and carry forward the most recent thread state.
DO $$
DECLARE
  v_thread record;
BEGIN
  FOR v_thread IN
    SELECT
      user_id,
      (array_agg(id ORDER BY created_at, id))[1] AS keep_id,
      (array_agg(subject ORDER BY updated_at DESC, id DESC))[1] AS subject,
      'open'::text AS status,
      (array_agg(last_message ORDER BY updated_at DESC, id DESC))[1] AS last_message,
      (array_agg(last_message_at ORDER BY updated_at DESC, id DESC))[1] AS last_message_at,
      sum(user_unread_count)::integer AS user_unread_count,
      sum(admin_unread_count)::integer AS admin_unread_count,
      min(created_at) AS created_at,
      max(updated_at) AS updated_at
    FROM public.support_conversations
    WHERE user_role = 'vendor'
    GROUP BY user_id
  LOOP
    UPDATE public.support_messages AS message
    SET conversation_id = v_thread.keep_id
    FROM public.support_conversations AS duplicate
    WHERE duplicate.user_id = v_thread.user_id
      AND duplicate.user_role = 'vendor'
      AND duplicate.id <> v_thread.keep_id
      AND message.conversation_id = duplicate.id;

    UPDATE public.support_conversations
    SET subject = v_thread.subject,
        status = v_thread.status,
        last_message = v_thread.last_message,
        last_message_at = v_thread.last_message_at,
        user_unread_count = v_thread.user_unread_count,
        admin_unread_count = v_thread.admin_unread_count,
        created_at = v_thread.created_at,
        updated_at = v_thread.updated_at
    WHERE id = v_thread.keep_id;

    DELETE FROM public.support_conversations
    WHERE user_id = v_thread.user_id
      AND user_role = 'vendor'
      AND id <> v_thread.keep_id;
  END LOOP;
END
$$;

CREATE UNIQUE INDEX IF NOT EXISTS support_one_vendor_thread_per_user
  ON public.support_conversations(user_id)
  WHERE user_role = 'vendor';

CREATE OR REPLACE FUNCTION public.support_start_conversation(
  p_user_id text, p_user_role text, p_subject text, p_body text
) RETURNS public.support_conversations
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_conversation public.support_conversations;
  v_message public.support_messages;
BEGIN
  IF p_user_role IS DISTINCT FROM 'vendor'
     OR NOT public.support_actor(p_user_id, p_user_role)
     OR length(btrim(p_subject)) NOT BETWEEN 1 AND 120
     OR length(p_body) NOT BETWEEN 1 AND 4000
     OR length(btrim(p_body)) = 0 THEN
    RAISE EXCEPTION 'Invalid support conversation' USING ERRCODE = '22023';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(p_user_id, 0));

  SELECT * INTO v_conversation
  FROM public.support_conversations
  WHERE user_id = p_user_id AND user_role = 'vendor'
  FOR UPDATE;

  IF v_conversation.id IS NULL THEN
    INSERT INTO public.support_conversations(
      user_id, user_role, subject, last_message, last_message_at,
      status, admin_unread_count
    ) VALUES (
      p_user_id, 'vendor', btrim(p_subject), btrim(p_body),
      clock_timestamp(), 'open', 1
    ) RETURNING * INTO v_conversation;
  ELSE
    UPDATE public.support_conversations
    SET status = 'open',
        last_message = btrim(p_body),
        last_message_at = clock_timestamp(),
        updated_at = clock_timestamp(),
        admin_unread_count = admin_unread_count + 1
    WHERE id = v_conversation.id
    RETURNING * INTO v_conversation;
  END IF;

  INSERT INTO public.support_messages(
    conversation_id, sender_user_id, sender_role, body
  ) VALUES (
    v_conversation.id, p_user_id, 'vendor', btrim(p_body)
  ) RETURNING * INTO v_message;

  UPDATE public.support_conversations
  SET last_message_at = v_message.created_at,
      updated_at = v_message.created_at
  WHERE id = v_conversation.id
  RETURNING * INTO v_conversation;

  RETURN v_conversation;
END
$$;

REVOKE ALL ON FUNCTION public.support_start_conversation(text,text,text,text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.support_start_conversation(text,text,text,text)
  TO service_role;

COMMIT;
