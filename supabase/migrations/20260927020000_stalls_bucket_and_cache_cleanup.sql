-- 1. Ensure stalls bucket exists in storage.buckets as a public bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('stalls', 'stalls', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 2. Ensure public access policy exists for stalls bucket
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

-- 3. Clean up dead /cache/ temporary strings in products and stall_holders
UPDATE products
SET image_url = NULL
WHERE image_url ILIKE '%/cache/scaled_%'
   OR image_url ILIKE '%/cache/image_picker%';

UPDATE stall_holders
SET banner_image_url = NULL
WHERE banner_image_url ILIKE '%/cache/scaled_%'
   OR banner_image_url ILIKE '%/cache/image_picker%';
