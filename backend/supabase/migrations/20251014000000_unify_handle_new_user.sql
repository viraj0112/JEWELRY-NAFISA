-- Drop the existing trigger and function to apply a safer version
-- Drop the existing trigger and function to apply the final, unified version
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

-- Create a robust function that handles essential user creation,
-- including credits and referral code, without crashing.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  -- Insert essential data, plus credits and a new referral code
  INSERT INTO public.users (
    id,
    email,
    username,
    role,
    credits_remaining,
    referral_code
  )
  VALUES (
    NEW.id,
    NEW.email,
    -- Use the part of the email before the '@' as a fallback username
    COALESCE(NEW.raw_user_meta_data ->> 'username', split_part(NEW.email, '@', 1)),
    -- Safely assign a default role
    'member',
    -- Safely get signup credits from settings table, defaulting to 1 if not found
    (SELECT value::INT FROM public.settings WHERE key = 'signup_bonus_credits' LIMIT 1),
    -- Generate a unique 8-character referral code
    substring(replace(gen_random_uuid()::text, '-', ''), 1, 8)
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate the trigger to execute the function on new user creation
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();