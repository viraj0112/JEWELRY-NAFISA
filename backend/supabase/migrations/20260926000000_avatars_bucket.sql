-- Profile pictures from the Edit Profile dialog (edit_profile_dialog.dart ->
-- UserProfileProvider.updateUserProfile) are uploaded to the 'avatars' bucket
-- at '<user id>/avatar.<ext>' and shown through getPublicUrl().
--
-- No migration ever created this bucket. In production its public URL answers
-- "Bucket not found", so either it is missing (every upload fails) or it is
-- private (uploads work but the picture never loads). This fixes both cases.
--
-- Non-destructive in the same way as 20260716120000: no existing policy is
-- dropped, and policies are only created when absent by name.

-- Create the bucket, or make an existing one public: getPublicUrl() links only
-- resolve on a public bucket, and avatars are shown to everyone anyway.
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Each user may only write inside their own '<user id>/' folder. Upload uses
-- upsert, which needs INSERT, UPDATE and SELECT on the object.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname = 'Anyone can read avatars'
  ) THEN
    CREATE POLICY "Anyone can read avatars"
    ON storage.objects FOR SELECT TO public
    USING (bucket_id = 'avatars');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname = 'Users can upload their own avatar'
  ) THEN
    CREATE POLICY "Users can upload their own avatar"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (
      bucket_id = 'avatars'
      AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname = 'Users can replace their own avatar'
  ) THEN
    CREATE POLICY "Users can replace their own avatar"
    ON storage.objects FOR UPDATE TO authenticated
    USING (
      bucket_id = 'avatars'
      AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
    )
    WITH CHECK (
      bucket_id = 'avatars'
      AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname = 'Users can delete their own avatar'
  ) THEN
    CREATE POLICY "Users can delete their own avatar"
    ON storage.objects FOR DELETE TO authenticated
    USING (
      bucket_id = 'avatars'
      AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
    );
  END IF;
END
$$;
