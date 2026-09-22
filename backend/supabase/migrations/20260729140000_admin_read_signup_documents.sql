-- ============================================================================
-- Let admins read B2B registration documents in User Management
-- ----------------------------------------------------------------------------
-- `pending_signup_uploads` was created with RLS ENABLED and no policy at all
-- (migration 20260306000000). Only the edge functions, which use service_role
-- and bypass RLS, could ever read it. From the admin app the query returned an
-- empty set — no error, just nothing — which is why the User Management screen
-- showed no documents for users awaiting approval.
--
-- That empty-not-error behaviour is worth remembering: a missing SELECT policy
-- is indistinguishable from "no rows" at the client. A missing GRANT, by
-- contrast, raises 42501. Silent-empty is the harder of the two to debug.
--
-- Documents matter most exactly while a user is pending: `finalize-signup-uploads`
-- only runs after they confirm their email and sign in, so during the entire
-- review window the uploads live here and nowhere else.
-- ============================================================================

ALTER TABLE public.pending_signup_uploads ENABLE ROW LEVEL SECURITY;

-- Admins may read every pending upload (review + approval workflow).
DROP POLICY IF EXISTS "Admins can read pending signup uploads"
  ON public.pending_signup_uploads;
CREATE POLICY "Admins can read pending signup uploads"
  ON public.pending_signup_uploads
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND role = 'admin'::user_role
    )
  );

-- A user may read the rows for their own address, so the B2B signup screen can
-- show upload status. Scoped by email because these rows predate the user row.
DROP POLICY IF EXISTS "Users can read their own pending uploads"
  ON public.pending_signup_uploads;
CREATE POLICY "Users can read their own pending uploads"
  ON public.pending_signup_uploads
  FOR SELECT TO authenticated
  USING (lower(email) = lower(auth.jwt() ->> 'email'));

GRANT SELECT ON public.pending_signup_uploads TO authenticated;

-- ----------------------------------------------------------------------------
-- Storage: the `designer-files` bucket is PRIVATE (public = false), so the
-- `getPublicUrl()` links stored in "designer-files".file_url by
-- finalize-signup-uploads do not actually resolve. The admin screen therefore
-- derives the object path and mints a short-lived signed URL instead. That
-- needs SELECT on storage.objects, which migration 20251009000001 already
-- grants to every authenticated user for this bucket — restated here so the
-- dependency is explicit rather than accidental.
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Allow authenticated users to read from designer-files"
  ON storage.objects;
CREATE POLICY "Allow authenticated users to read from designer-files"
  ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'designer-files');
