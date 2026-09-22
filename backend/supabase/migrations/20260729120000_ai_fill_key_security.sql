-- ============================================================================
-- AI Data-Fill: master-key TTL + encryption-at-rest for LLM keys
-- ----------------------------------------------------------------------------
-- Three problems this fixes:
--
--  1. `x_api_key` (the B2B "master key") lived in the table as plaintext and
--     never expired. We now store a SHA-256 *hash* for lookup and an AES-GCM
--     *ciphertext* for the one place that must replay the key (the edge
--     function calling the FastAPI backend). The plaintext is shown to the
--     admin exactly once, at generation time. This is the standard
--     "hash for verify, show once" API-key pattern (GitHub/Stripe style).
--
--  2. `llm_api_key` (the user's own provider key) was stored plaintext AND
--     selected straight back into the browser, so anyone with the user's
--     session — or a DB dump — read it verbatim. It is now stored only as
--     AES-256-GCM ciphertext. The encryption key lives in the Edge Function /
--     backend environment, NOT in Postgres, so a database dump alone is
--     useless. The UI gets `llm_key_hint` (last 4 chars) for recognition.
--
--  3. No TTL. `expires_at` NULL = never expires; otherwise the key is refused
--     by both the edge function and the FastAPI backend once past it.
--
-- Column-level GRANTs (below) are what actually stop the browser from reading
-- the secret columns — RLS filters *rows*, it cannot hide a column.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. New columns.
-- ----------------------------------------------------------------------------
ALTER TABLE public.api_credentials
  ADD COLUMN IF NOT EXISTS x_api_key_hash text,      -- sha256(plaintext), hex
  ADD COLUMN IF NOT EXISTS x_api_key_enc  text,      -- v1.<b64 iv>.<b64 ct+tag>
  ADD COLUMN IF NOT EXISTS key_prefix     text,      -- e.g. 'dgn_4452abeb' (display only)
  ADD COLUMN IF NOT EXISTS expires_at     timestamptz, -- NULL = never expires
  ADD COLUMN IF NOT EXISTS llm_api_key_enc text,     -- v1.<b64 iv>.<b64 ct+tag>
  ADD COLUMN IF NOT EXISTS llm_key_hint    text,     -- last 4 chars, for the UI
  ADD COLUMN IF NOT EXISTS last_used_at    timestamptz;

-- Legacy rows still carry a plaintext x_api_key; new rows do not write it.
-- Dropping NOT NULL lets `issue_key` insert hash+ciphertext only.
ALTER TABLE public.api_credentials ALTER COLUMN x_api_key DROP NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_api_credentials_key_hash
  ON public.api_credentials (x_api_key_hash)
  WHERE x_api_key_hash IS NOT NULL;

COMMENT ON COLUMN public.api_credentials.x_api_key IS
  'DEPRECATED plaintext key, kept only so keys issued before 2026-07-29 keep working. Rotate the user to clear it.';
COMMENT ON COLUMN public.api_credentials.llm_api_key IS
  'DEPRECATED plaintext LLM key. Superseded by llm_api_key_enc; nulled on next save.';
COMMENT ON COLUMN public.api_credentials.expires_at IS
  'Master-key TTL. NULL means never expires.';

-- ----------------------------------------------------------------------------
-- 2. Column-level privileges.
--    RLS already restricts *which rows* a user sees. This restricts *which
--    columns* — without it, `select('*')` from the browser still returns the
--    ciphertext and (for legacy rows) the plaintext key.
-- ----------------------------------------------------------------------------
REVOKE SELECT, INSERT, UPDATE ON public.api_credentials FROM authenticated;

GRANT SELECT (
  user_id, llm_model, llm_key_hint, is_active, key_prefix,
  expires_at, last_used_at, created_at, updated_at
) ON public.api_credentials TO authenticated;

-- Users may change only their preferred model directly. Anything touching a
-- secret goes through the `ai-credentials` edge function, which does the
-- encryption; there is no path for the browser to write a raw key again.
GRANT UPDATE (llm_model) ON public.api_credentials TO authenticated;

-- The backend + edge functions use service_role, which bypasses all of this.
GRANT SELECT, INSERT, UPDATE, DELETE ON public.api_credentials TO service_role;

-- Same reasoning for the global admin key: it should never reach a browser.
-- The columns must exist BEFORE the GRANT that names them, otherwise the hint
-- column is left ungranted and every read of it fails with 42501.
ALTER TABLE public.llm_settings
  ADD COLUMN IF NOT EXISTS global_llm_api_key_enc text,
  ADD COLUMN IF NOT EXISTS global_llm_key_hint    text;

REVOKE SELECT, INSERT, UPDATE ON public.llm_settings FROM authenticated;
GRANT SELECT (id, default_model, global_llm_key_hint, updated_by, updated_at)
  ON public.llm_settings TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.llm_settings TO service_role;

COMMENT ON COLUMN public.llm_settings.global_llm_api_key IS
  'DEPRECATED plaintext key. Superseded by global_llm_api_key_enc.';

-- ----------------------------------------------------------------------------
-- 3. Expiry-aware view of a user''s own credential, for the UI.
--    SECURITY INVOKER so RLS still applies; it just derives display state.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.api_credential_status
WITH (security_invoker = true) AS
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
FROM public.api_credentials c;

GRANT SELECT ON public.api_credential_status TO authenticated, service_role;
