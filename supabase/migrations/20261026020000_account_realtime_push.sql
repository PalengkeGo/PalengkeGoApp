BEGIN;

-- Realtime delivers the account status and moderation notice without polling.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'users'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.users;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
END $$;

CREATE TABLE public.account_device_tokens (
  user_id text NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,
  token text PRIMARY KEY CHECK (length(token) BETWEEN 20 AND 4096),
  platform text NOT NULL CHECK (platform IN ('android', 'iOS', 'linux', 'macOS', 'windows', 'fuchsia')),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.account_device_tokens ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.account_device_tokens FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.account_device_tokens TO service_role;
CREATE INDEX account_device_tokens_user_id_idx ON public.account_device_tokens(user_id);

COMMIT;
