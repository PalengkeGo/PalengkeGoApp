-- Keep the admin publish payload compatible even if the earlier popup
-- announcement migration was not applied to an existing database.
ALTER TABLE public.system_announcements
  ADD COLUMN IF NOT EXISTS image_url text,
  ADD COLUMN IF NOT EXISTS show_as_popup boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS facebook_url text,
  ADD COLUMN IF NOT EXISTS popup_image_urls jsonb NOT NULL DEFAULT '[]'::jsonb;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'system_announcements'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.system_announcements;
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';
