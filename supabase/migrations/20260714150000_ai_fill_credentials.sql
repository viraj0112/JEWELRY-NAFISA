-- ============================================================================
-- AI Data-Fill credentials & settings
-- ----------------------------------------------------------------------------
-- Supports the "AI Data Fill" feature:
--   * Every user gets an x-api-key (issued by admin) used to authenticate to
--     the DatabasePrefill FastAPI backend.
--   * Each user MAY store their own LLM API key + preferred model.
--   * Admin stores a single GLOBAL LLM key + default model as the fallback.
-- Precedence at request time: user's own LLM key/model  ->  admin global.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Per-user credentials.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.api_credentials (
  user_id       uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  x_api_key     text UNIQUE NOT NULL,       -- issued by admin; sent as x-api-key header
  llm_api_key   text,                       -- user's own LLM key (optional)
  llm_model     text,                       -- user's preferred model (optional)
  is_active     boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

-- Fast lookup by the header value the backend receives.
CREATE INDEX IF NOT EXISTS idx_api_credentials_x_api_key
  ON public.api_credentials (x_api_key);

-- ----------------------------------------------------------------------------
-- 2. Global (admin) LLM settings — single row, id=1.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.llm_settings (
  id                integer PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  global_llm_api_key text,
  default_model      text NOT NULL DEFAULT 'gemini-2.5-pro',
  updated_by         uuid REFERENCES public.users(id),
  updated_at         timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.llm_settings (id, default_model)
VALUES (1, 'gemini-2.5-pro')
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 3. updated_at trigger for api_credentials.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.touch_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_api_credentials_updated ON public.api_credentials;
CREATE TRIGGER trg_api_credentials_updated
  BEFORE UPDATE ON public.api_credentials
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- ----------------------------------------------------------------------------
-- 4. RLS.
--    - A user can read/update their OWN credential row (to set their LLM key).
--    - Admins have full access to everything (issue keys, set global settings).
--    - The FastAPI backend uses the service_role key, which bypasses RLS, to
--      resolve an incoming x-api-key -> user across all rows.
-- ----------------------------------------------------------------------------
ALTER TABLE public.api_credentials ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.llm_settings    ENABLE ROW LEVEL SECURITY;

-- api_credentials: own row
DROP POLICY IF EXISTS "cred_select_own" ON public.api_credentials;
CREATE POLICY "cred_select_own" ON public.api_credentials
  FOR SELECT TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "cred_update_own" ON public.api_credentials;
CREATE POLICY "cred_update_own" ON public.api_credentials
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- api_credentials: admin full access (relies on non-recursive public.is_admin())
DROP POLICY IF EXISTS "cred_admin_all" ON public.api_credentials;
CREATE POLICY "cred_admin_all" ON public.api_credentials
  FOR ALL TO authenticated
  USING (public.is_admin()) WITH CHECK (public.is_admin());

-- llm_settings: everyone authenticated may READ the default model (not secrets
-- — see note below); only admins may write.
DROP POLICY IF EXISTS "llm_admin_all" ON public.llm_settings;
CREATE POLICY "llm_admin_all" ON public.llm_settings
  FOR ALL TO authenticated
  USING (public.is_admin()) WITH CHECK (public.is_admin());

GRANT SELECT, INSERT, UPDATE ON public.api_credentials TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE ON public.llm_settings    TO authenticated, service_role;
