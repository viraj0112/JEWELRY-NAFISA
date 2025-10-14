
CREATE OR REPLACE FUNCTION public.get_top_referrers(limit_count INT)
RETURNS TABLE(user_id UUID, username TEXT, email TEXT, referral_count BIGINT) AS $$
BEGIN
  RETURN QUERY
  SELECT
    r.referrer_id AS user_id,
    u.username,
    u.email,
    COUNT(r.id) AS referral_count
  FROM
    public.referrals r
  JOIN
    public.users u ON r.referrer_id = u.id
  GROUP BY
    r.referrer_id, u.username, u.email
  ORDER BY
    referral_count DESC
  LIMIT
    limit_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION public.get_settings()
RETURNS jsonb AS $$
DECLARE
  settings_jsonb jsonb;
BEGIN
  SELECT jsonb_object_agg(key, value)
  INTO settings_jsonb
  FROM public.settings;

  RETURN settings_jsonb;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;