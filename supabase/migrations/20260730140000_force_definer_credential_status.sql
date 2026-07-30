-- ============================================================================
-- Fix (round 2): 42501 "permission denied for table api_credentials"
-- ----------------------------------------------------------------------------
-- Background — two ways a view can read its base table:
--
--   security_invoker = true   base-table privileges are checked against the
--                             CALLER (here: the `authenticated` role).
--   security_invoker = false  (PostgreSQL's default) they are checked against
--                             the view's OWNER. This is the classic "privilege
--                             bridge": the view becomes the only door into a
--                             table the caller cannot open directly.
--
-- 20260729120000 deliberately revoked table-level SELECT on api_credentials and
-- handed out column-level grants instead, so the browser can never pull the
-- encrypted key columns. An invoker view sitting on top of that table is
-- therefore reading with a role that has no table-level SELECT — hence 42501,
-- reported against the base table rather than the view.
--
-- 20260730120000 tried to flip the view to definer by re-issuing
-- CREATE OR REPLACE VIEW without the WITH (...) clause. That is exactly the
-- assumption worth removing: the reloptions behaviour of a replace is a subtle
-- corner, and if the flag survives, the migration is a silent no-op. Here we
-- state the flag outright with ALTER VIEW — and do it AFTER the replace, since
-- the replace is what rewrites the options list in the first place.
--
-- Security note: with a definer view, RLS on api_credentials no longer filters
-- reads made through this view, so the view's own WHERE clause IS the access
-- control. It mirrors the cred_select_own / cred_admin_all policies exactly.
-- Secret columns are simply not in the select list, and the browser still has
-- no table-level grant, so there is no path to them.
-- ============================================================================

CREATE OR REPLACE VIEW public.api_credential_status AS
SELECT
  c.user_id,
  c.key_prefix,
  c.llm_model,
  c.llm_key_hint,
  c.is_active,
  c.expires_at,
  c.last_used_at,
  c.created_at,
  (c.expires_at IS NOT NULL AND c.expires_at <= now()) AS is_expired,
  (c.is_active AND (c.expires_at IS NULL OR c.expires_at > now())) AS is_usable
FROM public.api_credentials c
WHERE c.user_id = auth.uid() OR public.is_admin();

-- The whole point of this migration. Must come after the CREATE OR REPLACE.
ALTER VIEW public.api_credential_status SET (security_invoker = false);

-- The bridge only works if the owner can actually read the table. Migrations
-- normally run as `postgres`, which owns api_credentials; if this database was
-- set up differently the ALTER is not ours to make, and the existing owner is
-- already a privileged role — so a failure here is not fatal.
DO $$
BEGIN
  ALTER VIEW public.api_credential_status OWNER TO postgres;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Left api_credential_status owner unchanged: %', SQLERRM;
END $$;

-- Read path for the AI Fill screen + the admin credential list.
GRANT SELECT ON public.api_credential_status TO authenticated, service_role;

-- Write path for "save my model preference". The view is auto-updatable, and a
-- definer view only exposes the rows its WHERE clause admits, so a user can
-- never write another user's row even without a WHERE of their own.
GRANT UPDATE (llm_model) ON public.api_credential_status TO authenticated;

-- Base-table grants restated so the non-secret columns stay readable to any
-- other code path, and so a future revert to an invoker view degrades to
-- "reads the safe columns" rather than "reads nothing". Idempotent.
GRANT SELECT (
  user_id, llm_model, llm_key_hint, is_active, key_prefix,
  expires_at, last_used_at, created_at, updated_at
) ON public.api_credentials TO authenticated;
GRANT UPDATE (llm_model) ON public.api_credentials TO authenticated;

-- ----------------------------------------------------------------------------
-- Verification (run in the SQL editor after pushing):
--
--   SELECT relname, relowner::regrole, reloptions
--   FROM pg_class WHERE relname = 'api_credential_status';
--   -- expect reloptions NULL (or without security_invoker=true)
--
--   SET LOCAL ROLE authenticated;
--   SELECT * FROM public.api_credential_status;   -- expect 0 rows, not 42501
--   RESET ROLE;
-- ----------------------------------------------------------------------------
