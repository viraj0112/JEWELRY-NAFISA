-- 1. Create the function
CREATE OR REPLACE FUNCTION get_email_by_username(p_username TEXT)
RETURNS TABLE (email TEXT) AS $$
BEGIN
  RETURN QUERY
  SELECT u.email FROM public.users AS u
  WHERE u.username = p_username;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Grant access to the 'anon' role (unauthenticated users)
GRANT EXECUTE ON FUNCTION public.get_email_by_username(TEXT) TO anon;