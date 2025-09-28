CREATE TABLE IF NOT EXISTS public.settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  description TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins have full access to settings"
ON public.settings FOR ALL
USING (
  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin'::user_role)
);

INSERT INTO public.settings (key, value, description) VALUES
  ('daily_reset_time_utc', '00:00', 'The time (UTC) when member credits are reset daily.'),
  ('signup_bonus_credits', '1', 'Credits awarded to a new user on signup.'),
  ('referral_bonus_member', '3', 'Credits awarded to a member for a successful referral.'),
  ('referral_bonus_non_member', '2', 'Credits awarded to a non-member for a successful referral.')
ON CONFLICT (key) DO NOTHING;

CREATE OR REPLACE FUNCTION get_settings()
RETURNS jsonb AS $$
BEGIN
  RETURN (SELECT jsonb_object_agg(key, value) FROM public.settings);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION update_setting(p_key TEXT, p_value TEXT)
RETURNS void AS $$
DECLARE
  hour_val INT;
  minute_val INT;
  cron_schedule TEXT;
BEGIN
  INSERT INTO public.settings (key, value, updated_at)
  VALUES (p_key, p_value, NOW())
  ON CONFLICT (key) DO UPDATE
  SET value = EXCLUDED.value, updated_at = NOW();

  IF p_key = 'daily_reset_time_utc' THEN
    PERFORM cron.unschedule('reset-daily-credits');

    hour_val := SPLIT_PART(p_value, ':', 1)::INT;
    minute_val := SPLIT_PART(p_value, ':', 2)::INT;
    cron_schedule := minute_val || ' ' || hour_val || ' * * *';

    PERFORM cron.schedule(
      'reset-daily-credits',
      cron_schedule,
      'SELECT public.reset_daily_credits_for_members()'
    );
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;