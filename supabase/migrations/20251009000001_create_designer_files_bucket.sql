INSERT INTO storage.buckets (id, name, public)
VALUES ('designer-files', 'designer-files', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Allow authenticated users to upload to designer-files" ON storage.objects;
CREATE POLICY "Allow authenticated users to upload to designer-files"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'designer-files');

DROP POLICY IF EXISTS "Allow authenticated users to read from designer-files" ON storage.objects;
CREATE POLICY "Allow authenticated users to read from designer-files"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'designer-files');