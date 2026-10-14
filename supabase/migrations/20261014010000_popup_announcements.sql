ALTER TABLE public.system_announcements
  ADD COLUMN IF NOT EXISTS show_as_popup boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS facebook_url text,
  ADD COLUMN IF NOT EXISTS popup_image_urls jsonb NOT NULL DEFAULT '[]'::jsonb;
