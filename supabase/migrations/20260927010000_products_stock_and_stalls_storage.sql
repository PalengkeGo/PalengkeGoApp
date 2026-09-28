-- 1. Ensure stock_quantity exists on products with positive default
ALTER TABLE products ADD COLUMN IF NOT EXISTS stock_quantity DOUBLE PRECISION DEFAULT 5.0;

-- 2. Backfill existing in-stock products that have 0 or NULL stock to 5.0
UPDATE products
SET stock_quantity = 5.0
WHERE (stock_quantity IS NULL OR stock_quantity <= 0)
  AND (is_in_stock = TRUE OR is_visible = TRUE);

-- 3. Storage bucket policies for stalls imagery (products and stall branding)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'objects' AND schemaname = 'storage' AND policyname = 'Public stalls access'
  ) THEN
    CREATE POLICY "Public stalls access" ON storage.objects
    FOR ALL USING (bucket_id = 'stalls') WITH CHECK (bucket_id = 'stalls');
  END IF;
END $$;
