-- ============================================================================
-- Fix (final): 42501 "permission denied for table llm_settings"
-- ----------------------------------------------------------------------------
-- Same root cause as 20260730140000, one table over.
--
-- 20260729120000 revoked table-level SELECT on llm_settings and handed out
-- column-level grants instead, so the browser could never pull
-- global_llm_api_key_enc. The catch with a column-only table: PostgreSQL checks
-- table-level SELECT first, and only on failure falls back to checking each
-- referenced column. If ANY referenced column is ungranted the whole statement
-- aborts, and the error names the TABLE, not the column — which is why this
-- reads as a blanket 403 rather than "column global_llm_key_hint".
--
-- 20260729130000 tried to repair the grant list. That keeps the read path
-- coupled to a grant list that must be re-audited every time a column is added
-- — the failure mode we have now hit twice. So: apply the same fix the
-- credentials screen already uses. A SECURITY DEFINER view is a privilege
-- bridge — base-table privileges are checked against the view's OWNER, not the
-- caller — so the client needs no grant on llm_settings whatsoever, and a
-- future column addition cannot re-break the read.
--
-- Because a definer view bypasses the base table's RLS, the view's WHERE and
-- select list ARE the access control:
--   * default_model is not a secret — every authenticated user may read it
--     (the fill backend falls back to it), matching the intent in
--     20260714150000.
--   * global_llm_key_hint only tells you whether a global key is configured,
--     but it is admin-facing, so it is nulled for non-admins.
--   * The key columns are simply not in the select list. There is no path.
-- ============================================================================

CREATE OR REPLACE VIEW public.llm_settings_public AS
SELECT
  s.id,
  s.default_model,
  CASE WHEN public.is_admin() THEN s.global_llm_key_hint END AS global_llm_key_hint,
  (s.global_llm_api_key_enc IS NOT NULL
     OR NULLIF(s.global_llm_api_key, '') IS NOT NULL)            AS has_global_key,
  s.updated_at
FROM public.llm_settings s;

-- The whole point: read with the owner's privileges, not the caller's.
ALTER VIEW public.llm_settings_public SET (security_invoker = false);

-- The bridge only works if the owner can read the base table. Migrations run as
-- `postgres`, which owns llm_settings; if this database was provisioned
-- differently the existing owner is already privileged, so a failure is benign.
DO $$
BEGIN
  ALTER VIEW public.llm_settings_public OWNER TO postgres;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Left llm_settings_public owner unchanged: %', SQLERRM;
END $$;

GRANT SELECT ON public.llm_settings_public TO authenticated, service_role;

-- Writes still go through the `ai-credentials` edge function (service_role),
-- which encrypts before storing. No client write path is opened here.

-- Restate the base-table grants so any other code path keeps working and so a
-- future revert to reading the table degrades to "reads the safe columns"
-- rather than "reads nothing". Idempotent.
GRANT SELECT (id, default_model, global_llm_key_hint, updated_by, updated_at)
  ON public.llm_settings TO authenticated;

-- ----------------------------------------------------------------------------
-- Verification (Supabase SQL editor, after push):
--
--   SELECT relname, relowner::regrole, reloptions
--   FROM pg_class WHERE relname = 'llm_settings_public';
--   -- expect reloptions NULL (or without security_invoker=true)
--
--   SET LOCAL ROLE authenticated;
--   SELECT * FROM public.llm_settings_public;   -- expect a row, not 42501
--   RESET ROLE;
-- ----------------------------------------------------------------------------
