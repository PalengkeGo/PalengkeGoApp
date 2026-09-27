-- Migration to support user cart synchronization in Supabase
CREATE TABLE IF NOT EXISTS public.carts (
  uid TEXT PRIMARY KEY,
  items JSONB NOT NULL DEFAULT '[]'::jsonb,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.carts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own cart" ON public.carts;
CREATE POLICY "Users can manage own cart" ON public.carts
  FOR ALL
  USING (true)
  WITH CHECK (true);
