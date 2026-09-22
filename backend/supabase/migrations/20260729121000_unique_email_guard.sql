-- ============================================================================
-- Registration: reject an email that is already registered
-- ----------------------------------------------------------------------------
-- The signup forms relied on one heuristic: after auth.signUp(), Supabase
-- returns an obfuscated user with an EMPTY `identities` array when the address
-- already exists. That only happens when "Confirm email" is enabled AND email
-- enumeration protection is on, and the app then swallowed the resulting
-- exception and returned null — so the user just saw a generic failure, or
-- (with confirmations off) a silent no-op.
--
-- Two layers are added here:
--   1. `public.email_is_registered()` — a cheap pre-flight check the form can
--      run BEFORE doing any work (the business form uploads two files before
--      it ever calls signUp; failing after that upload is pure waste).
--   2. A unique index on public.users(lower(email)) so the database itself
--      refuses a duplicate even if some future code path skips the check.
--      Defence in depth: application checks race, constraints don't.
--
-- NOTE ON ENUMERATION: an endpoint that answers "is this email registered?"
-- lets someone probe for accounts. That is the unavoidable cost of telling a
-- legitimate user "this email is taken" at the form. We keep the blast radius
-- small: boolean-only answer, no user data, and it is not usable to log in.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Pre-flight check.
--    SECURITY DEFINER because `auth.users` is not readable by anon/authenticated.
--    search_path is pinned so a caller cannot shadow `auth` with their own schema.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.email_is_registered(p_email text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_email     text := lower(trim(p_email));
  v_confirmed boolean;
  v_found     boolean := false;
BEGIN
  IF v_email IS NULL OR v_email = '' THEN
    RETURN jsonb_build_object('exists', false, 'confirmed', false);
  END IF;

  SELECT (u.email_confirmed_at IS NOT NULL)
    INTO v_confirmed
  FROM auth.users u
  WHERE lower(u.email) = v_email
  LIMIT 1;

  v_found := FOUND;

  RETURN jsonb_build_object(
    'exists',    v_found,
    'confirmed', COALESCE(v_confirmed, false)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.email_is_registered(text) FROM public;
GRANT EXECUTE ON FUNCTION public.email_is_registered(text) TO anon, authenticated;

COMMENT ON FUNCTION public.email_is_registered(text) IS
  'Pre-flight signup check. Returns {exists, confirmed}. Boolean-only by design.';

-- ----------------------------------------------------------------------------
-- 2. Database-level guarantee.
--    If this fails, the mirror table already holds duplicates. Find them with:
--      SELECT lower(email), count(*) FROM public.users
--      WHERE email IS NOT NULL GROUP BY 1 HAVING count(*) > 1;
--    and merge/delete before re-running.
-- ----------------------------------------------------------------------------
CREATE UNIQUE INDEX IF NOT EXISTS users_email_lower_unique
  ON public.users (lower(email))
  WHERE email IS NOT NULL;
