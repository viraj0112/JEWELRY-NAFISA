-- These views expose only non-secret columns and rely on the underlying table
-- RLS policies. Use caller privileges so Advisor does not report them as
-- SECURITY DEFINER views.
--
-- Keep the secret-column check behind a narrowly scoped function. The function
-- returns only whether a key exists; it never exposes the key itself.
CREATE OR REPLACE FUNCTION public.llm_settings_has_global_key()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.llm_settings
    WHERE global_llm_api_key_enc IS NOT NULL
       OR NULLIF(global_llm_api_key, '') IS NOT NULL
  );
$$;

REVOKE ALL ON FUNCTION public.llm_settings_has_global_key() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.llm_settings_has_global_key()
  TO authenticated, service_role;

CREATE OR REPLACE VIEW public.llm_settings_public AS
SELECT
  s.id,
  s.default_model,
  CASE WHEN public.is_admin() THEN s.global_llm_key_hint END AS global_llm_key_hint,
  public.llm_settings_has_global_key() AS has_global_key,
  s.updated_at
FROM public.llm_settings s;

ALTER VIEW public.api_credential_status
  SET (security_invoker = true);

ALTER VIEW public.llm_settings_public
  SET (security_invoker = true);
