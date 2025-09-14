-- Enable pg_cron extension if not already enabled
CREATE EXTENSION IF NOT EXISTS pg_cron;
-- Schedule the reset_daily_credits_for_members function to run daily at midnight UTC
-- You can change the schedule as needed, e.g., '0 0 * * *' for midnight UTC
SELECT cron.schedule(
    'reset-daily-credits',
    '0 0 * * *',
    'SELECT public.reset_daily_credits_for_members()'
);