-- Allow authenticated users to create their own Users row
-- This migration should be applied after RLS has been enabled on the users table

DROP POLICY IF EXISTS "Users can create their own profile" ON public.users;
CREATE POLICY "Users can create their own profile"
  ON public.users
  FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Optionally allow service_role or other roles if needed (do not enable by default here)
-- GRANT USAGE to roles can be added separately if required.
