-- Function to reset daily credits for members
CREATE OR REPLACE FUNCTION public.reset_daily_credits_for_members()
RETURNS void AS $$
BEGIN
  UPDATE public.users
  SET
    credits_remaining = 3,
    last_credit_refresh = NOW()
  WHERE
    is_member = TRUE
    AND (last_credit_refresh IS NULL OR last_credit_refresh < NOW() - INTERVAL '24 hours');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;