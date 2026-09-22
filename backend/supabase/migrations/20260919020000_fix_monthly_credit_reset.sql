-- ============================================================================
-- Fix: monthly credit reset never fires, so credits have to be set by hand
-- ----------------------------------------------------------------------------
-- The cron entry runs on the 1st ('0 0 1 * *'), but the function only touched
-- users whose last refresh was MORE THAN 28 DAYS old:
--
--     WHERE is_member = TRUE
--       AND (last_credit_refresh IS NULL
--            OR last_credit_refresh < NOW() - INTERVAL '28 days')
--
-- That rolling window is a leftover from the original DAILY job
-- (20250915010000, INTERVAL '24 hours' on a '0 0 * * *' schedule), where it
-- was a sensible idempotency guard. Carried over to a monthly calendar
-- schedule it actively fights it:
--
--  1. A manual refresh disables the next automatic one. The admin screen's
--     refreshAllUserCredits() stamps last_credit_refresh = now() on EVERY
--     user. Refresh by hand on the 15th -> the 1st is only 17 days later ->
--     everyone is skipped -> you refresh by hand again -> which poisons the
--     month after. Self-perpetuating, and exactly why this always needed doing
--     manually.
--  2. March is skipped every non-leap year even with a healthy cron: Feb 1
--     00:00 -> Mar 1 00:00 is EXACTLY 28 days, and the comparison is a strict
--     '<', so it is false.
--  3. Any single-user credit edit (setUserCredits) skips that user next month.
--
-- FIX: ask "has this user been refreshed since the 1st of THIS month?" instead
-- of measuring a rolling interval. Still idempotent if the job runs twice in a
-- day, but immune to mid-month manual edits and to calendar arithmetic.
--
-- The body below is dollar-quoted, deliberately. The Supabase SQL *editor*
-- mangles dollar-quoted pastes, but the *CLI* is the opposite: supabase db
-- push splits a migration file on semicolons and does respect dollar quoting,
-- whereas a standard SQL-body function (whose semicolons sit inside no quote
-- at all) gets cut mid-statement and fails with "syntax error at end of
-- input". Since this is applied with db push, dollar quoting is the form that
-- works. Note there are no quote tags written anywhere in these comments - a
-- stray tag in a comment can desynchronise that splitter.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.reset_monthly_credits()
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $fn$
  UPDATE public.users
  SET credits_remaining = CASE
        WHEN is_member THEN
          COALESCE((SELECT value::int FROM public.settings
                     WHERE key = 'monthly_credits_member'), 30)
        ELSE
          COALESCE((SELECT value::int FROM public.settings
                     WHERE key = 'monthly_credits_non_member'), 5)
      END,
      last_credit_refresh = now()
  WHERE last_credit_refresh IS NULL
     OR last_credit_refresh < date_trunc('month', now());
$fn$;

-- ----------------------------------------------------------------------------
-- Lock the function down.
--
-- Production currently has GRANT ALL on this function to `anon` AND
-- `authenticated` (see prod_schema.sql). It is SECURITY DEFINER and owned by
-- postgres, so ANY unauthenticated caller could
--     POST /rest/v1/rpc/reset_monthly_credits
-- and rewrite every user's balance - resetting paying members to the
-- non-member amount and wiping the last_credit_refresh baseline for everyone.
-- CREATE OR REPLACE preserves existing grants, so this has to be explicit.
--
-- Only the scheduler (and anything else running as service_role) needs it.
-- ----------------------------------------------------------------------------
REVOKE EXECUTE ON FUNCTION public.reset_monthly_credits() FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.reset_monthly_credits() TO service_role;

-- ----------------------------------------------------------------------------
-- Make sure the job actually exists.
--
-- The migration that was supposed to schedule this
-- (2025102622000_update_monthly_credit_reset.sql) carries a 13-digit version
-- instead of Supabase's 14-digit YYYYMMDDHHMMSS, which can cause it to be
-- skipped or mis-ordered - a plausible reason production has the function but
-- may have no cron entry. Re-assert it idempotently.
--
-- Wrapped: on a database where pg_cron is not installed this raises rather
-- than silently doing nothing, and a failure here must not roll back the
-- function fix above.
-- ----------------------------------------------------------------------------
DO $sched$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'reset-monthly-credits') THEN
    PERFORM cron.schedule(
      'reset-monthly-credits',
      '0 0 1 * *',                                   -- 1st of the month, 00:00 UTC
      'SELECT public.reset_monthly_credits()'
    );
    RAISE NOTICE 'Scheduled cron job reset-monthly-credits.';
  ELSE
    RAISE NOTICE 'Cron job reset-monthly-credits already present; left as is.';
  END IF;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Could not verify/create the reset-monthly-credits cron job: %. Enable pg_cron and re-run the DO block.', SQLERRM;
END
$sched$;

-- ----------------------------------------------------------------------------
-- Verification:
--
--   SELECT jobid, jobname, schedule, active FROM cron.job;
--   SELECT jobid, status, return_message, start_time
--     FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10;
--
--   -- Who would the new rule touch right now? (0 is correct if credits were
--   -- already refreshed this calendar month.)
--   SELECT count(*) FILTER (WHERE last_credit_refresh IS NULL
--                              OR last_credit_refresh < date_trunc('month', now())) AS would_refresh,
--          count(*) AS total
--     FROM public.users;
-- ----------------------------------------------------------------------------
