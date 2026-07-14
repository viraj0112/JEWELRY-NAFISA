-- ============================================================================
-- Fix infinite recursion (42P17) in RLS on public.users.
-- ----------------------------------------------------------------------------
-- Root cause: the SELECT policy on public.users was
--     (is_admin() OR auth.uid() = id)
-- and is_admin() itself runs `SELECT ... FROM public.users`, which re-triggers
-- the very same policy -> infinite recursion. This fires on EVERY read of
-- public.users, including a user fetching their own row at login, so it breaks
-- login for everyone.
--
-- Fix has two independent parts, either of which stops the login-path
-- recursion; together they are robust:
--
--   1. Make is_admin() read the role from auth.users' JWT metadata (a
--      DIFFERENT table, in the auth schema) instead of from public.users.
--      A lookup that never touches public.users cannot recurse on it,
--      regardless of the function owner's role attributes. SECURITY DEFINER +
--      pinned search_path keeps it callable by anon/authenticated safely.
--
--   2. Split the users policies so a normal user reading their OWN row matches
--      a simple non-recursive policy (auth.uid() = id) and never calls
--      is_admin() at all. Admins get a SEPARATE policy for reading OTHER rows.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Non-recursive admin check: read role from auth.users metadata.
--    We check BOTH app_metadata (authoritative, server-set) and user_metadata
--    (where this project currently stores role) so existing users keep working.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'auth', 'public'
AS $function$
  SELECT COALESCE(
    (SELECT
        (u.raw_app_meta_data  ->> 'role') = 'admin'
     OR (u.raw_user_meta_data ->> 'role') = 'admin'
     FROM auth.users u
     WHERE u.id = auth.uid()),
    false
  );
$function$;

GRANT EXECUTE ON FUNCTION public.is_admin() TO anon, authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 2. Rebuild the users SELECT policies so the self-read path is non-recursive.
--    Drop every historical variant we've seen on this table first.
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Admins can view all users"        ON public.users;
DROP POLICY IF EXISTS "Admins can view all user profiles" ON public.users;
DROP POLICY IF EXISTS "Users can read own data"          ON public.users;

-- Everyone authenticated can read their own row — simple, cannot recurse.
CREATE POLICY "Users can read own data"
  ON public.users FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

-- Admins can additionally read all rows. is_admin() no longer queries
-- public.users, so this does not recurse.
CREATE POLICY "Admins can view all users"
  ON public.users FOR SELECT
  TO authenticated
  USING (public.is_admin());

-- Keep admin UPDATE working with the now non-recursive is_admin().
DROP POLICY IF EXISTS "Admins can update users" ON public.users;
CREATE POLICY "Admins can update users"
  ON public.users FOR UPDATE
  TO authenticated
  USING (public.is_admin());
