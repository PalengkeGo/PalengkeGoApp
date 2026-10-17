-- Ensure the account cart table matches SupabaseCartRepository even when a
-- legacy `carts` table was created before the JSON cart migration.
CREATE TABLE IF NOT EXISTS public.carts (
  uid TEXT PRIMARY KEY,
  items JSONB NOT NULL DEFAULT '[]'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.carts
  ADD COLUMN IF NOT EXISTS uid TEXT,
  ADD COLUMN IF NOT EXISTS items JSONB NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

CREATE UNIQUE INDEX IF NOT EXISTS carts_uid_unique_idx
  ON public.carts (uid);

ALTER TABLE public.carts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own cart" ON public.carts;
CREATE POLICY "Users can manage own cart" ON public.carts
  FOR ALL USING (TRUE) WITH CHECK (TRUE);
