CREATE POLICY "Allow anon signup uploads to pending designer files"
ON storage.objects
FOR INSERT
TO anon
WITH CHECK (
  bucket_id = 'designer-files'
  AND (storage.foldername(name))[1] = 'pending'
);
