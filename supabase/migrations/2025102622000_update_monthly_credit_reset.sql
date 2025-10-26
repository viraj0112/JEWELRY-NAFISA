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
    AND (last_credit_refresh IS NULL OR last_credit_refresh < NOW() - INTERVAL '28 days'); -- Fixed: Semicolon removed

  -- Update non-members' credits
  UPDATE public.users
  SET
    credits_remaining = non_member_credits,
    last_credit_refresh = NOW()
  WHERE
    is_member = FALSE
    AND (last_credit_refresh IS NULL OR last_credit_refresh < NOW() - INTERVAL '28 days'); -- Fixed: Semicolon removed and uncommented

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop the old daily cron job (will fail if it doesn't exist, which is OK)
SELECT cron.unschedule('reset-daily-credits');

-- Schedule the NEW function to run monthly (at 00:00 UTC on the 1st of every month)
SELECT cron.schedule(
    'reset-monthly-credits',
    '0 0 1 * *', -- 1st day of month at 00:00
    'SELECT public.reset_monthly_credits()'
);

-- Grant permission
GRANT EXECUTE ON FUNCTION public.reset_monthly_credits() TO service_role;