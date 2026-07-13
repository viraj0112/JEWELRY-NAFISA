-- Drop the old function if it exists
DROP FUNCTION IF EXISTS public.reset_daily_credits_for_members();

-- Create the new function for monthly reset
CREATE OR REPLACE FUNCTION public.reset_monthly_credits()
RETURNS void AS $$
DECLARE
  member_credits INT;
  non_member_credits INT;
BEGIN
  -- Get credit amounts from settings
  SELECT COALESCE((SELECT value::INT FROM public.settings WHERE key = 'monthly_credits_member'), 30) INTO member_credits;
  SELECT COALESCE((SELECT value::INT FROM public.settings WHERE key = 'monthly_credits_non_member'), 5) INTO non_member_credits;

  -- Update members' credits
  UPDATE public.users
  SET
    credits_remaining = member_credits,
    last_credit_refresh = NOW()
  WHERE
    is_member = TRUE
    AND (last_credit_refresh IS NULL OR last_credit_refresh < NOW() - INTERVAL '28 days');

  -- Update non-members' credits
  UPDATE public.users
  SET
    credits_remaining = non_member_credits,
    last_credit_refresh = NOW()
  WHERE
    is_member = FALSE
    AND (last_credit_refresh IS NULL OR last_credit_refresh < NOW() - INTERVAL '28 days');

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop the old daily cron job if it exists (safe version)
DO $$
BEGIN
  PERFORM cron.unschedule('reset-daily-credits');
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Schedule the NEW function to run monthly (at 00:00 UTC on the 1st of every month)
-- Only schedule if not already scheduled
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'reset-monthly-credits') THEN
    PERFORM cron.schedule(
        'reset-monthly-credits',
        '0 0 1 * *', -- 1st day of month at 00:00
        'SELECT public.reset_monthly_credits()'
    );
  END IF;
END $$;

-- Grant permission
GRANT EXECUTE ON FUNCTION public.reset_monthly_credits() TO service_role;