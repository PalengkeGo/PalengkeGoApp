ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS payment_intent_id TEXT;

CREATE INDEX IF NOT EXISTS idx_orders_payment_intent_id
  ON public.orders(payment_intent_id);
