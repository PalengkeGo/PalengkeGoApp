-- Convert product_id to TEXT to support flexible string IDs and UUIDs
-- Add full RLS policies for products (INSERT, UPDATE, DELETE)

-- 1. Drop referencing foreign key constraints
ALTER TABLE cart DROP CONSTRAINT IF EXISTS cart_product_id_fkey;
ALTER TABLE order_items DROP CONSTRAINT IF EXISTS order_items_product_id_fkey;
ALTER TABLE product_category_cross_tag DROP CONSTRAINT IF EXISTS product_category_cross_tag_product_id_fkey;

-- 2. Alter column types on products and referencing tables
ALTER TABLE products ALTER COLUMN product_id DROP DEFAULT;
ALTER TABLE products ALTER COLUMN product_id TYPE TEXT;
ALTER TABLE products ALTER COLUMN product_id SET DEFAULT gen_random_uuid()::text;

ALTER TABLE cart ALTER COLUMN product_id TYPE TEXT;
ALTER TABLE order_items ALTER COLUMN product_id TYPE TEXT;
ALTER TABLE product_category_cross_tag ALTER COLUMN product_id TYPE TEXT;

-- 3. Re-add foreign keys
ALTER TABLE cart ADD CONSTRAINT cart_product_id_fkey FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE;
ALTER TABLE order_items ADD CONSTRAINT order_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES products(product_id);
ALTER TABLE product_category_cross_tag ADD CONSTRAINT product_category_cross_tag_product_id_fkey FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE;

-- 4. Drop restrictive category & unit check constraints if present
ALTER TABLE products DROP CONSTRAINT IF EXISTS products_category_tag_check;
ALTER TABLE products DROP CONSTRAINT IF EXISTS products_unit_check;

-- 5. Add any missing columns
ALTER TABLE products ADD COLUMN IF NOT EXISTS stock_quantity DOUBLE PRECISION DEFAULT 0;
ALTER TABLE products ADD COLUMN IF NOT EXISTS description TEXT DEFAULT '';
ALTER TABLE products ADD COLUMN IF NOT EXISTS discount_percentage DOUBLE PRECISION;

-- 6. Add RLS policies for products
DROP POLICY IF EXISTS "Allow anon insert products" ON public.products;
DROP POLICY IF EXISTS "Allow anon update products" ON public.products;
DROP POLICY IF EXISTS "Allow anon delete products" ON public.products;
DROP POLICY IF EXISTS "Allow all products access" ON public.products;

CREATE POLICY "Allow anon insert products" ON public.products FOR INSERT WITH CHECK (TRUE);
CREATE POLICY "Allow anon update products" ON public.products FOR UPDATE USING (TRUE);
CREATE POLICY "Allow anon delete products" ON public.products FOR DELETE USING (TRUE);
