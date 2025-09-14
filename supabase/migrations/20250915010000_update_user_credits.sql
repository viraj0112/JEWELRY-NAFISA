-- Add columns to track credit refresh logic
ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS credits_remaining INT NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_credit_refresh TIMESTAMPTZ;

-- Function to grant initial credits on signup (1 for non-members)
CREATE OR REPLACE FUNCTION public.grant_initial_credits()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.users
  SET credits_remaining = 1
  WHERE id = NEW.id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to grant credits to a new user
CREATE TRIGGER on_user_created_grant_credits
  AFTER INSERT ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.grant_initial_credits();

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