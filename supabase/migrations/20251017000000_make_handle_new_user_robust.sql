-- Inserts a new row into public.users and, if the user is a designer,
-- also into public.designer_profiles.

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  user_role public.user_role;
BEGIN
  -- Insert into public.users table
  INSERT INTO public.users (id, email, full_name, role, referral_code)
  VALUES (
    new.id,
    new.email,
    new.raw_user_meta_data->>'full_name',
    (new.raw_user_meta_data->>'role')::public.user_role,
    -- Generates a unique 8-character referral code
    left(md5(random()::text), 8)
  );

  -- If the new user has the 'designer' role, create a designer profile
  user_role := (new.raw_user_meta_data->>'role')::public.user_role;
  IF user_role = 'designer' THEN
    INSERT INTO public.designer_profiles (user_id, business_name, business_type, phone, address, gst_number)
    VALUES (
      new.id,
      new.raw_user_meta_data->>'business_name',
      (new.raw_user_meta_data->>'business_type')::public.business_type,
      new.raw_user_meta_data->>'phone',
      new.raw_user_meta_data->>'address',
      new.raw_user_meta_data->>'gst_number'
    );
  END IF;

  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;