
CREATE OR REPLACE FUNCTION public.update_setting(p_key TEXT, p_value TEXT)
RETURNS void AS $$
BEGIN

  INSERT INTO public.settings (key, value)
  VALUES (p_key, p_value)
  ON CONFLICT (key) 
  DO UPDATE SET 
    value = EXCLUDED.value, 
    updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;