-- The app keys its JSON cart rows by Firebase `uid`. Older carts schemas also
-- have a required `user_id`; keep that legacy field nullable for new rows.
ALTER TABLE public.carts
  ADD COLUMN IF NOT EXISTS user_id TEXT;

ALTER TABLE public.carts
  ALTER COLUMN user_id DROP NOT NULL;
