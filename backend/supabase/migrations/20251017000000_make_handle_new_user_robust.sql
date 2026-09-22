CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  user_role public.user_role;
  signup_credits INT;
BEGIN
  -- 1. Get signup credits (safely default to 0 if setting missing)
  SELECT value::INT INTO signup_credits FROM public.settings WHERE key = 'signup_bonus_credits';
  
  -- 2. Insert into public.users (Restoring missing fields from previous versions)
  INSERT INTO public.users (
    id,
    email,
    username,
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
    new.id,
    new.email,
    -- Use username from metadata, or fallback to email prefix
    COALESCE(new.raw_user_meta_data ->> 'username', split_part(new.email, '@', 1)),
    -- Cast role safely
    COALESCE((new.raw_user_meta_data ->> 'role')::public.user_role, 'member'),
    -- Use fetched credits or default to 0
    COALESCE(signup_credits, 0),
    -- Generate Referral Code
    substring(replace(gen_random_uuid()::text, '-', ''), 1, 8),
    -- Metadata fields
    new.raw_user_meta_data ->> 'business_name',
    new.raw_user_meta_data ->> 'business_type',
    new.raw_user_meta_data ->> 'phone',
    new.raw_user_meta_data ->> 'address',
    new.raw_user_meta_data ->> 'gst_number'
  );

  -- 3. Handle Designer Profile Creation
  user_role := (new.raw_user_meta_data->>'role')::public.user_role;
  
  IF user_role = 'designer' THEN
    INSERT INTO public.designer_profiles (
        user_id, 
        business_name, 
        business_type, 
        phone, 
        address, 
        gst_number
    )
    VALUES (
      new.id,
      new.raw_user_meta_data->>'business_name',
      -- FIX: Cast to correct type 'designer_role_type' OR remove cast if just storing text
      -- If 'designer_role_type' is the correct enum:
      (new.raw_user_meta_data->>'business_type')::public.designer_role_type, 
      new.raw_user_meta_data->>'phone',
      new.raw_user_meta_data->>'address',
      new.raw_user_meta_data->>'gst_number'
    );
  END IF;

  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;