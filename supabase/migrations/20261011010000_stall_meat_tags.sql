-- Preserve registered meat types for the market Beef/Pork filters.
ALTER TABLE public.stall_holders
  ADD COLUMN IF NOT EXISTS tags text[] NOT NULL DEFAULT '{}';
ALTER TABLE public.stall_holders
  ADD CONSTRAINT stall_meat_tags_valid CHECK (tags <@ ARRAY['Beef', 'Pork']::text[]);
