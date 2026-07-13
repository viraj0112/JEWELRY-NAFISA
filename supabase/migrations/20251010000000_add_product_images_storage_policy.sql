--
-- RLS policy for product-images bucket
--
DROP POLICY IF EXISTS "Allow public read access to product-images" ON storage.objects;
CREATE POLICY "Allow public read access to product-images" ON storage.objects FOR
SELECT
  USING (bucket_id = 'product-images');

DROP POLICY IF EXISTS "Allow authenticated uploads to product-images" ON storage.objects;
CREATE POLICY "Allow authenticated uploads to product-images" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'product-images');