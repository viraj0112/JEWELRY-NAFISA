-- The 'manufacturer-files' and 'designer-files' buckets are written by B2B
-- single + bulk upload (sinlgeFile.dart, bulkUpload.dart). Both already exist
-- in production, created by hand in the dashboard and never captured in a
-- migration - so a fresh/local/staging database has no such bucket and every
-- upload there fails with "Bucket not found".
--
-- This migration makes those environments match production. It is deliberately
-- non-destructive: production already has policies on these buckets that are
-- not recorded anywhere in this repo, so nothing here drops or replaces an
-- existing policy. Re-running it against production is a no-op.

-- Create the bucket only where it is missing. Existing buckets (and their
-- public flag) are left exactly as configured.
INSERT INTO storage.buckets (id, name, public)
VALUES ('manufacturer-files', 'manufacturer-files', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
VALUES ('designer-files', 'designer-files', true)
ON CONFLICT (id) DO NOTHING;

-- Baseline policies, added only if absent by name. These mirror the intent of
-- the existing designer-files policies in 20251009000001: authenticated users
-- may upload, and anyone may read (the upload code hands out getPublicUrl()
-- links, which only resolve on a public bucket).
--
-- NOTE: production carries additional policies on these buckets that are not
-- reproduced here because they predate version control. Do not add DROP POLICY
-- statements to this file - that would silently discard them.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname = 'Allow authenticated users to upload to manufacturer-files'
  ) THEN
    CREATE POLICY "Allow authenticated users to upload to manufacturer-files"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'manufacturer-files');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname = 'Allow public read access to manufacturer-files'
  ) THEN
    CREATE POLICY "Allow public read access to manufacturer-files"
    ON storage.objects FOR SELECT TO public
    USING (bucket_id = 'manufacturer-files');
  END IF;
END
$$;
