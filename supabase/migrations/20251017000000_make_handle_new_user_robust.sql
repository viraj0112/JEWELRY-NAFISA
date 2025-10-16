
-- Drop the old trigger and function to ensure a clean replacement
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

-- Create the new, robust function
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (
    id,
    email,
    -- Use the unique ID as the default username to prevent collisions
    username,
    full_name,
    role,
    credits_remaining,
    referral_code,
    business_name,
    business_type,
    phone,
    address,
    gst_number
  )
  VALUES (
    NEW.id,
    NEW.email,
    -- Set username to the new user's ID, which is guaranteed to be unique.
    NEW.id::text,
    NEW.raw_user_meta_data ->> 'business_name', -- Use business name for the 'full_name' field
    COALESCE((NEW.raw_user_meta_data ->> 'role')::user_role, 'member'),
    (SELECT value::INT FROM public.settings WHERE key = 'signup_bonus_credits' LIMIT 1),
    substring(replace(gen_random_uuid()::text, '-', ''), 1, 8),
    NEW.raw_user_meta_data ->> 'business_name',
    NEW.raw_user_meta_data ->> 'business_type',
    NEW.raw_user_meta_data ->> 'phone',
    NEW.raw_user_meta_data ->> 'address',
    NEW.raw_user_meta_data ->> 'gst_number'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate the trigger to use the new function
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();