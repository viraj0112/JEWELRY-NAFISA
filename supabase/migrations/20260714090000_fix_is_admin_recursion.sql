-- ============================================================================
-- Fix infinite recursion (42P17) in is_admin() when called from a policy on
-- public.users itself.
-- ----------------------------------------------------------------------------
-- is_admin() is SECURITY DEFINER and its owner (postgres) has BYPASSRLS
-- locally, so the recursion doesn't reproduce in every environment — but
-- relying on the function owner's role attributes is fragile across
-- environments (dashboard-created functions can end up owned by a role
-- without BYPASSRLS). `SET row_security = off` inside the function makes the
-- internal lookup ignore RLS unconditionally, regardless of owner, which is
-- the standard fix for this class of recursive-policy bug.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
SET row_security TO 'off'
AS $function$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.users
    WHERE id = auth.uid()
    AND role = 'admin'::user_role
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.is_admin() TO anon, authenticated, service_role;
