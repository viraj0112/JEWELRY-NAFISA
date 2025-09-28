CREATE OR REPLACE FUNCTION get_top_referrers(limit_count INT)
RETURNS TABLE(
  user_id UUID,
  username TEXT,
  email TEXT,
  referral_count BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    u.id as user_id,
    u.username,
    u.email,
    COUNT(r.referrer_id) as referral_count
  FROM
    public.referrals r
  JOIN
    public.users u ON r.referrer_id = u.id
  GROUP BY
    u.id, u.username, u.email
  ORDER BY
    referral_count DESC
  LIMIT limit_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;