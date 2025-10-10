INSERT INTO storage.buckets (id, name, public)
VALUES ('designer-files', 'designer-files', false);

CREATE POLICY "Allow authenticated users to upload to designer-files"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'designer-files');

CREATE POLICY "Allow authenticated users to read from designer-files"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'designer-files');