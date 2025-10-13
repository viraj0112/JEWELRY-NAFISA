CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  signup_credits INT;
BEGIN
  
  SELECT value::INT INTO signup_credits FROM public.settings WHERE key = 'signup_bonus_credits';


  INSERT INTO public.users (
    id, email, username, birthdate, role,
    business_name, business_type, phone, credits_remaining
  )
  VALUES (
    NEW.id, NEW.email,
    COALESCE(
      NEW.raw_user_meta_data ->> 'username',
      NEW.raw_user_meta_data ->> 'business_name'
    ),
    (NEW.raw_user_meta_data ->> 'birthdate')::date,
    COALESCE((NEW.raw_user_meta_data ->> 'role')::user_role, 'member'),
    NEW.raw_user_meta_data ->> 'business_name',
    NEW.raw_user_meta_data ->> 'business_type',
    NEW.raw_user_meta_data ->> 'phone',
    COALESCE(signup_credits, 1) 
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION public.reset_daily_credits_for_members()
RETURNS void AS $$
BEGIN
  UPDATE public.users
  SET credits_remaining = 3  
  WHERE is_member = TRUE;
END;
$$ LANGUAGE plpgsql;


--  #######################
DO $$
DECLARE
  signup_credits INT;
BEGIN
  -- Get the default sign-up credits from your settings
  SELECT value::INT INTO signup_credits FROM public.settings WHERE key = 'signup_bonus_credits';

  -- Update non-members who currently have 0 credits
  UPDATE public.users
  SET credits_remaining = COALESCE(signup_credits, 1) -- Sets credits from settings, or 1 if setting not found
  WHERE credits_remaining = 0 AND is_member = FALSE;

  -- Update members who currently have 0 credits to their daily amount
  UPDATE public.users
  SET credits_remaining = 3 -- As defined in your daily reset function
  WHERE credits_remaining = 0 AND is_member = TRUE;
END $$;