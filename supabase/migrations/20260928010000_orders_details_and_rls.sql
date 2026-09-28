-- Migration: orders details and RLS fix
-- Ensure complete customer details (phone, name, address, notes) and unblock orders flow

ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS customer_name TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS customer_phone TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS is_priority BOOLEAN DEFAULT FALSE;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS priority_fee DOUBLE PRECISION DEFAULT 0;

-- Convert order_id to TEXT in orders, order_items, and order_status_history to accept both UUID and formatted order numbers
ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_stall_holder_id_fkey;
ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_customer_id_fkey;

ALTER TABLE public.order_items DROP CONSTRAINT IF EXISTS order_items_order_id_fkey;
ALTER TABLE public.order_items DROP CONSTRAINT IF EXISTS order_items_product_id_fkey;

ALTER TABLE public.order_status_history DROP CONSTRAINT IF EXISTS order_status_history_order_id_fkey;

ALTER TABLE public.orders ALTER COLUMN order_id TYPE TEXT;
ALTER TABLE public.order_items ALTER COLUMN order_id TYPE TEXT;
ALTER TABLE public.order_status_history ALTER COLUMN order_id TYPE TEXT;
ALTER TABLE public.order_items ALTER COLUMN product_id TYPE TEXT;

ALTER TABLE public.order_items
  ADD CONSTRAINT order_items_order_id_fkey
  FOREIGN KEY (order_id) REFERENCES public.orders(order_id) ON DELETE CASCADE;

ALTER TABLE public.order_status_history
  ADD CONSTRAINT order_status_history_order_id_fkey
  FOREIGN KEY (order_id) REFERENCES public.orders(order_id) ON DELETE CASCADE;

-- Enable RLS and add public permissive policies
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can insert orders" ON public.orders;
CREATE POLICY "Anyone can insert orders" ON public.orders FOR INSERT WITH CHECK (TRUE);

DROP POLICY IF EXISTS "Anyone can select orders" ON public.orders;
CREATE POLICY "Anyone can select orders" ON public.orders FOR SELECT USING (TRUE);

DROP POLICY IF EXISTS "Anyone can update orders" ON public.orders;
CREATE POLICY "Anyone can update orders" ON public.orders FOR UPDATE USING (TRUE);

ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can manage order_items" ON public.order_items;
CREATE POLICY "Anyone can manage order_items" ON public.order_items FOR ALL USING (TRUE) WITH CHECK (TRUE);

ALTER TABLE public.order_status_history ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can manage order_status_history" ON public.order_status_history;
CREATE POLICY "Anyone can manage order_status_history" ON public.order_status_history FOR ALL USING (TRUE) WITH CHECK (TRUE);

GRANT ALL ON public.orders TO anon, authenticated, service_role;
GRANT ALL ON public.order_items TO anon, authenticated, service_role;
GRANT ALL ON public.order_status_history TO anon, authenticated, service_role;
