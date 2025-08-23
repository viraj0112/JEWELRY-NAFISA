DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

DROP FUNCTION IF EXISTS public.handle_new_user();

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (
    id, email, username, birthdate, role,
    business_name, business_type, phone
  )
  VALUES (
    NEW.id, NEW.email,
    COALESCE(
      NEW.raw_user_meta_data ->> 'username',
      NEW.raw_user_meta_data ->> 'business_name'
    ),
    (NEW.raw_user_meta_data ->> 'birthdate')::date,
    (NEW.raw_user_meta_data ->> 'role')::user_role,
    NEW.raw_user_meta_data ->> 'business_name',
    NEW.raw_user_meta_data ->> 'business_type',
    NEW.raw_user_meta_data ->> 'phone'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public; 

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();