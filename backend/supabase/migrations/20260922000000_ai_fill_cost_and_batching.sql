-- ============================================================================
-- AI Data-Fill: per-run cost tracking + batch settings
-- ----------------------------------------------------------------------------
-- 1. ai_fill_usage records the model and exact token counts Gemini reported
--    for every run, plus the cost computed from the admin's price table at the
--    time of the run (so later price edits don't rewrite history).
-- 2. llm_model_pricing: admin-maintained USD prices per 1M tokens, per model.
--    Prices change and new models appear, so they live in data, not code.
-- 3. llm_settings gains the batch knobs (batch size, pause between batches,
--    requests/minute) that keep large fills under Gemini's RPM/TPM limits.
-- 4. ai_fill_batch_settings(): the two non-secret batch values, readable by
--    every signed-in user (llm_settings itself is admin-only under RLS).
-- 5. ai_fill_usage_by_user() gains token and cost totals.
-- Additive only: no existing rows or columns change meaning.
-- ============================================================================

-- 1. Usage log ----------------------------------------------------------------
ALTER TABLE public.ai_fill_usage
  ADD COLUMN IF NOT EXISTS model           text,
  ADD COLUMN IF NOT EXISTS input_tokens    bigint NOT NULL DEFAULT 0,  -- includes cached_tokens
  ADD COLUMN IF NOT EXISTS cached_tokens   bigint NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS output_tokens   bigint NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS thinking_tokens bigint NOT NULL DEFAULT 0,  -- billed as output
  ADD COLUMN IF NOT EXISTS cost_usd        numeric(14, 6);             -- NULL = no price configured

-- 2. Price table --------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.llm_model_pricing (
  model                         text PRIMARY KEY
                                  CHECK (model ~ '^[A-Za-z0-9._-]{1,100}$'),
  input_usd_per_million         numeric(12, 6) NOT NULL CHECK (input_usd_per_million >= 0),
  output_usd_per_million        numeric(12, 6) NOT NULL CHECK (output_usd_per_million >= 0),
  -- Implicit-cache hits are billed at a discount; NULL = charge them at the
  -- normal input price (never under-reports cost).
  cached_input_usd_per_million  numeric(12, 6) CHECK (cached_input_usd_per_million >= 0),
  updated_by                    uuid REFERENCES public.users(id) ON DELETE SET NULL,
  updated_at                    timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.llm_model_pricing ENABLE ROW LEVEL SECURITY;

-- Prices aren't secret, but only admins manage them. The run-ai-fill Edge
-- Function reads them with the service role.
DROP POLICY IF EXISTS "llm_model_pricing_admin_all" ON public.llm_model_pricing;
CREATE POLICY "llm_model_pricing_admin_all" ON public.llm_model_pricing
  FOR ALL TO authenticated
  USING (public.is_admin()) WITH CHECK (public.is_admin());

GRANT SELECT, INSERT, UPDATE, DELETE ON public.llm_model_pricing TO authenticated;
GRANT ALL ON public.llm_model_pricing TO service_role;

-- 3. Batch settings -------------------------------------------------------------
ALTER TABLE public.llm_settings
  ADD COLUMN IF NOT EXISTS fill_batch_size          int NOT NULL DEFAULT 10
    CHECK (fill_batch_size BETWEEN 1 AND 100),
  ADD COLUMN IF NOT EXISTS fill_batch_pause_seconds int NOT NULL DEFAULT 10
    CHECK (fill_batch_pause_seconds BETWEEN 0 AND 600),
  ADD COLUMN IF NOT EXISTS llm_requests_per_minute  int NOT NULL DEFAULT 10
    CHECK (llm_requests_per_minute BETWEEN 0 AND 10000);   -- 0 = no limit

-- Column-level read grant for the admin screen (RLS still limits rows to
-- admins); writes go through the ai-credentials Edge Function.
GRANT SELECT (fill_batch_size, fill_batch_pause_seconds, llm_requests_per_minute)
  ON public.llm_settings TO authenticated;

CREATE OR REPLACE VIEW public.llm_settings_public
WITH (security_invoker = true) AS
SELECT
  s.id,
  s.default_model,
  CASE WHEN public.is_admin() THEN s.global_llm_key_hint END AS global_llm_key_hint,
  public.llm_settings_has_global_key() AS has_global_key,
  s.updated_at,
  s.fill_batch_size,
  s.fill_batch_pause_seconds,
  s.llm_requests_per_minute
FROM public.llm_settings s;

GRANT SELECT ON public.llm_settings_public TO authenticated, service_role;

-- 4. Batch values for every signed-in user --------------------------------------
CREATE OR REPLACE FUNCTION public.ai_fill_batch_settings()
RETURNS TABLE (fill_batch_size int, fill_batch_pause_seconds int)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT s.fill_batch_size, s.fill_batch_pause_seconds
  FROM public.llm_settings s
  WHERE s.id = 1;
$$;

REVOKE ALL ON FUNCTION public.ai_fill_batch_settings() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.ai_fill_batch_settings() TO authenticated, service_role;

-- 5. Usage report with tokens and cost ------------------------------------------
-- The return type changes, which CREATE OR REPLACE can't do.
DROP FUNCTION IF EXISTS public.ai_fill_usage_by_user(int);

CREATE FUNCTION public.ai_fill_usage_by_user(p_days int DEFAULT 30)
RETURNS TABLE (
  user_id        uuid,
  username       text,
  full_name      text,
  email          text,
  role           text,
  fill_runs      bigint,   -- number of invocations
  total_filled   bigint,   -- rows successfully written across all runs
  total_failed   bigint,
  last_used_at   timestamptz,
  total_tokens   bigint,   -- input + output + thinking
  total_cost_usd numeric,  -- sum over runs that had a price configured
  unpriced_runs  bigint    -- runs whose model had no price (cost unknown)
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Admin role required';
  END IF;

  RETURN QUERY
  SELECT
    u.id,
    u.username,
    u.full_name,
    u.email,
    u.role::text,
    count(a.id)                        AS fill_runs,
    coalesce(sum(a.success_count), 0)  AS total_filled,
    coalesce(sum(a.failed_count), 0)   AS total_failed,
    max(a.created_at)                  AS last_used_at,
    coalesce(sum(a.input_tokens + a.output_tokens + a.thinking_tokens), 0)::bigint
                                       AS total_tokens,
    coalesce(sum(a.cost_usd), 0)       AS total_cost_usd,
    count(a.id) FILTER (
      WHERE a.cost_usd IS NULL
        AND (a.input_tokens + a.output_tokens + a.thinking_tokens) > 0
    )                                  AS unpriced_runs
  FROM public.ai_fill_usage a
  JOIN public.users u ON u.id = a.user_id
  WHERE a.created_at >= now() - make_interval(days => p_days)
  GROUP BY u.id, u.username, u.full_name, u.email, u.role
  ORDER BY total_filled DESC, fill_runs DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.ai_fill_usage_by_user(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.ai_fill_usage_by_user(int) TO authenticated;
