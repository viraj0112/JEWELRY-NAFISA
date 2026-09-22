-- ============================================================================
-- Fix: is_admin() reads the role from a different place than the rest of the app
-- ----------------------------------------------------------------------------
-- 20260714090000 rewrote is_admin() to read the role out of auth.users JWT
-- metadata, to break an RLS recursion on public.users. That fixed the
-- recursion, but it also changed WHERE the role comes from - and nothing else
-- in this system agrees with it:
--
--   * public.users.role  <- profile_loader.dart, UserProfile.fromMap, and
--                           every edge function's requireAdmin() read this
--   * auth.users.raw_*_meta_data->>'role'  <- is_admin() reads this
--
-- The data only ever flows ONE way: handle_new_user() copies
-- raw_user_meta_data->>'role' into public.users.role at signup. Nothing writes
-- back. So any role granted after signup - which is how admins are actually
-- made - updates public.users.role while the auth metadata keeps whatever it
-- had at signup (usually 'member', or nothing at all). is_admin() then returns
-- FALSE for a real admin.
--
-- Visible symptom: an admin issues an AI-fill master key for a B2B user. The
-- edge function's requireAdmin() checks public.users.role, passes, and the row
-- IS written to api_credentials. The admin screen then reads it back through
-- api_credential_status, whose filter is
--     WHERE c.user_id = auth.uid() OR public.is_admin()
-- is_admin() is false, so the filter collapses to "my own row" and the key the
-- admin just issued is invisible - indistinguishable from "it was never
-- stored". Same for every other admin RLS policy built on is_admin().
--
-- FIX: accept either source. This only ever grants MORE than before (it is a
-- plain OR), so no existing admin loses access.
--
-- Why this still cannot recurse: the function is SECURITY DEFINER and
-- public.users is owned by `postgres`, and a table owner bypasses RLS unless
-- the table is set to FORCE ROW LEVEL SECURITY - which it is not, here or
-- anywhere in this schema. So the public.users read inside this function never
-- re-enters the policies that call it. (If FORCE RLS is ever turned on for
-- public.users, this function must be revisited.)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'auth', 'public'
AS $function$
  SELECT
    -- Source 1: JWT metadata (what 20260714090000 introduced). Kept so any
    -- admin who only exists in auth metadata keeps working.
    COALESCE(
      (SELECT (u.raw_app_meta_data  ->> 'role') = 'admin'
           OR (u.raw_user_meta_data ->> 'role') = 'admin'
         FROM auth.users u
        WHERE u.id = auth.uid()),
      false
    )
    OR
    -- Source 2: the app's actual source of truth.
    COALESCE(
      (SELECT u.role = 'admin'::public.user_role
         FROM public.users u
        WHERE u.id = auth.uid()),
      false
    );
$function$;

GRANT EXECUTE ON FUNCTION public.is_admin() TO anon, authenticated, service_role;

-- ----------------------------------------------------------------------------
-- Verification (run in the SQL editor after pushing):
--
--   -- Should now be true when signed in as an admin:
--   SELECT public.is_admin();
--
--   -- The two sources, side by side. Before this migration the right-hand
--   -- column was typically NULL for admins promoted after signup:
--   SELECT u.email, u.role AS public_users_role,
--          a.raw_app_meta_data  ->> 'role' AS app_meta_role,
--          a.raw_user_meta_data ->> 'role' AS user_meta_role
--     FROM public.users u JOIN auth.users a ON a.id = u.id
--    WHERE u.role = 'admin';
--
--   -- The credential list an admin should now see in full:
--   SELECT user_id, key_prefix, is_active, expires_at
--     FROM public.api_credential_status;
-- ----------------------------------------------------------------------------
