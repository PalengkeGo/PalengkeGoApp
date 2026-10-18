-- In-app messaging tables, indexes, realtime publication, and RLS policies

-- 1. Create conversations table
CREATE TABLE IF NOT EXISTS public.conversations (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    stall_id TEXT NOT NULL,
    stall_name TEXT NOT NULL,
    stall_avatar TEXT,
    customer_uid TEXT NOT NULL,
    customer_name TEXT NOT NULL,
    customer_avatar TEXT,
    last_message_text TEXT DEFAULT '',
    last_message_timestamp TIMESTAMPTZ DEFAULT NOW(),
    last_message_sender_id TEXT DEFAULT '',
    customer_unread_count INT DEFAULT 0,
    vendor_unread_count INT DEFAULT 0,
    inquiry_type TEXT DEFAULT 'general',
    related_order_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Create messages table
CREATE TABLE IF NOT EXISTS public.messages (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    conversation_id TEXT NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    sender_id TEXT NOT NULL,
    sender_name TEXT NOT NULL,
    sender_role TEXT NOT NULL CHECK (sender_role IN ('vendor', 'customer', 'admin')),
    text TEXT DEFAULT '',
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMPTZ,
    attachment_url TEXT,
    attachment_type TEXT
);

-- 3. Indexes for performance
CREATE INDEX IF NOT EXISTS idx_conversations_stall_id ON public.conversations(stall_id);
CREATE INDEX IF NOT EXISTS idx_conversations_customer_uid ON public.conversations(customer_uid);
CREATE INDEX IF NOT EXISTS idx_conversations_lookup ON public.conversations(stall_id, customer_uid);
CREATE INDEX IF NOT EXISTS idx_conversations_updated_at ON public.conversations(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_conversation ON public.messages(conversation_id, timestamp ASC);
CREATE INDEX IF NOT EXISTS idx_messages_unread ON public.messages(conversation_id, is_read) WHERE is_read = FALSE;

-- 4. Enable Supabase Realtime WebSocket publication safely
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'conversations'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
  END IF;
END $$;

-- 5. Row-Level Security (RLS)
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow manage conversations" ON public.conversations;
CREATE POLICY "Allow manage conversations" ON public.conversations
  FOR ALL
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "Allow manage messages" ON public.messages;
CREATE POLICY "Allow manage messages" ON public.messages
  FOR ALL
  USING (true)
  WITH CHECK (true);
