-- Schedule the reset_daily_credits_for_members function to run daily at midnight UTC
SELECT cron.schedule(
    'reset-daily-credits',
    '0 0 * * *',
    'SELECT public.reset_daily_credits_for_members()'
);