-- ============================================================================
-- Fix: 42501 "permission denied for table api_credentials" on the AI Data Fill screen
-- ----------------------------------------------------------------------------
-- PostgreSQL RLS requires table-level SELECT privilege to evaluate policies.
-- Because table-level SELECT was revoked on api_credentials to hide encrypted columns,
-- the security_invoker view api_credential_status fails when queried by authenticated users.
-- 
-- This migration converts the view to a standard security definer view (bypassing the
-- table-level RLS check) and manually enforces the RLS policies in its WHERE clause.
-- It also makes the view updatable so the frontend can save the llm_model preference
-- without needing table-level UPDATE on the base table.
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

-- Re-grant SELECT to ensure PostgREST cache is updated
GRANT SELECT ON public.api_credential_status TO authenticated, service_role;

-- Grant column-level UPDATE on the view so the frontend can save model preferences
GRANT UPDATE (llm_model) ON public.api_credential_status TO authenticated;
