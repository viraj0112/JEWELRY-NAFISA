-- ============================================================================
-- AI Data-Fill usage tracking
-- ----------------------------------------------------------------------------
-- One row per AI-fill invocation, written server-side by the `run-ai-fill`
-- Edge Function (service_role). This is the authoritative usage log: because
-- it is written at the server choke point and not by the client, it cannot be
-- skipped or spoofed, and it captures admins and B2B users alike (an admin is
-- just an ordinary auth.users row, so their fills land here automatically).
--
-- A per-event log (not a counter column on `users`) is deliberate: it records
-- WHEN, WHAT, and WHETHER-IT-SUCCEEDED, which is what enables trends, per-user
-- leaderboards, and rate-limiting. A single counter can't answer any of those.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.ai_fill_usage (
  id               bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  -- Keep the log row even if the user is later deleted (audit trail).
  user_id          uuid REFERENCES public.users(id) ON DELETE SET NULL,
  created_at       timestamptz NOT NULL DEFAULT now(),
  mode             text NOT NULL,          -- 'admin' (full-table) | 'mine' (own products)
  table_name       text,                   -- target table for admin fills; null for 'mine'
  requested_limit  int,                    -- how many rows the caller asked to fill
  total_processed  int NOT NULL DEFAULT 0, -- rows the backend actually looked at
  success_count    int NOT NULL DEFAULT 0, -- rows successfully written
  failed_count     int NOT NULL DEFAULT 0, -- rows that failed to fill
  http_status      int,                    -- backend HTTP status (200 = ok)
  ok               boolean NOT NULL DEFAULT true -- convenience flag: did the call succeed
);

-- "Usage for user X" and "usage over the last N days" are the two read paths.
CREATE INDEX IF NOT EXISTS idx_ai_fill_usage_user_id
  ON public.ai_fill_usage (user_id);
CREATE INDEX IF NOT EXISTS idx_ai_fill_usage_created_at
  ON public.ai_fill_usage (created_at DESC);

-- ----------------------------------------------------------------------------
-- RLS: only admins may read the raw log; the service_role (Edge Function)
-- bypasses RLS to insert. No authenticated user writes here directly.
-- ----------------------------------------------------------------------------
ALTER TABLE public.ai_fill_usage ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ai_fill_usage_admin_select" ON public.ai_fill_usage;
CREATE POLICY "ai_fill_usage_admin_select" ON public.ai_fill_usage
  FOR SELECT TO authenticated
  USING (public.is_admin());

GRANT SELECT ON public.ai_fill_usage TO authenticated;
GRANT INSERT, SELECT ON public.ai_fill_usage TO service_role;

-- ----------------------------------------------------------------------------
-- Reporting RPC: per-user usage rollup for the admin dashboard.
-- SECURITY DEFINER so it can read across all rows, but it hard-gates on
-- is_admin() first, so a non-admin calling it gets nothing.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.ai_fill_usage_by_user(p_days int DEFAULT 30)
RETURNS TABLE (
  user_id        uuid,
  username       text,
  full_name      text,
  email          text,
  role           text,
  fill_runs      bigint,   -- number of invocations
  total_filled   bigint,   -- rows successfully written across all runs
  total_failed   bigint,
  last_used_at   timestamptz
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
    max(a.created_at)                  AS last_used_at
  FROM public.ai_fill_usage a
  JOIN public.users u ON u.id = a.user_id
  WHERE a.created_at >= now() - make_interval(days => p_days)
  GROUP BY u.id, u.username, u.full_name, u.email, u.role
  ORDER BY total_filled DESC, fill_runs DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.ai_fill_usage_by_user(int) TO authenticated;
