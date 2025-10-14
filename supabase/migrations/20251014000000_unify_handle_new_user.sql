-- Drop the existing trigger and function to apply the unified version
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

-- Create a unified function to handle all user sign-up scenarios
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  signup_credits INT;
BEGIN
  -- Get the default sign-up credits from the settings table
  SELECT value::INT INTO signup_credits FROM public.settings WHERE key = 'signup_bonus_credits';

  -- Insert the new user into the public.users table
  INSERT INTO public.users (
    id, email, username, full_name, birthdate, role,
    business_name, business_type, phone, credits_remaining, avatar_url
  )
  VALUES (
    NEW.id,
    NEW.email,
    -- Prioritize username from form, then full_name from OAuth, then business_name
    COALESCE(
      NEW.raw_user_meta_data ->> 'username',
      NEW.raw_user_meta_data ->> 'full_name',
      NEW.raw_user_meta_data ->> 'business_name'
    ),
    NEW.raw_user_meta_data ->> 'full_name', -- Store full name if available
    (NEW.raw_user_meta_data ->> 'birthdate')::date,
    COALESCE((NEW.raw_user_meta_data ->> 'role')::user_role, 'member'),
    NEW.raw_user_meta_data ->> 'business_name',
    NEW.raw_user_meta_data ->> 'business_type',
    NEW.raw_user_meta_data ->> 'phone',
    COALESCE(signup_credits, 1),
    NEW.raw_user_meta_data ->> 'avatar_url' -- Store avatar from OAuth
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate the trigger to execute the function on new user creation
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();