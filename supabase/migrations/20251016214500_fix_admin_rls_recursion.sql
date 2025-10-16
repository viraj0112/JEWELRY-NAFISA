-- Function to securely get the role of the currently authenticated user from their JWT.
CREATE OR REPLACE FUNCTION get_my_role()
RETURNS TEXT AS $$
BEGIN
  RETURN auth.jwt()->>'role';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop the old, recursive policy if it exists
DROP POLICY IF EXISTS "Admins can view all user profiles" ON public.users;

-- Create the new, non-recursive policy for admins
CREATE POLICY "Admins can view all user profiles"
ON public.users FOR SELECT
TO authenticated
USING (
  get_my_role() = 'admin'
);