ALTER TABLE public.users
ADD COLUMN referred_by UUID REFERENCES public.users(id);

CREATE TABLE public.referrals (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  referrer_id UUID NOT NULL REFERENCES public.users(id),
  referred_id UUID NOT NULL REFERENCES public.users(id),
  credits_awarded INT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION public.increment_user_credits(user_id_to_update UUID, credits_to_add INT)
RETURNS VOID AS $$
BEGIN
  UPDATE public.users
  SET credits_remaining = credits_remaining + credits_to_add
  WHERE id = user_id_to_update;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;