-- ============================================================================
-- Fix: 42501 "permission denied for table llm_settings" on the AI Data Fill screen
-- ----------------------------------------------------------------------------
-- Migration 20260729120000 issued the column-level GRANT on llm_settings BEFORE
-- the ALTER TABLE that adds `global_llm_key_hint`, so the new column was never
-- granted to `authenticated`. The admin UI selects it, and a SELECT touching
-- even one ungranted column fails for the whole statement — which is why the
-- error is a blanket "permission denied for table", not a per-column message.
--
-- 20260729120000 has since been corrected for fresh installs; this migration
-- repairs databases that already applied the original version. It is safe to
-- run either way (GRANT is idempotent).
-- ============================================================================

GRANT SELECT (id, default_model, global_llm_key_hint, updated_by, updated_at)
  ON public.llm_settings TO authenticated;

-- Same audit applied to api_credentials: every column the client reads (directly
-- or through api_credential_status) must appear here.
GRANT SELECT (
  user_id, llm_model, llm_key_hint, is_active, key_prefix,
  expires_at, last_used_at, created_at, updated_at
) ON public.api_credentials TO authenticated;
