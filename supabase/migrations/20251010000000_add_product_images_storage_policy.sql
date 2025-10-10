CREATE POLICY "Allow admins to upload to product-images"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'product-images' AND
  (SELECT role FROM public.users WHERE id = auth.uid()) = 'admin'
);