-- Function to get the total count of users from the previous month
CREATE OR REPLACE FUNCTION get_total_users_previous_month()
RETURNS INT AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)
    FROM public.users
    WHERE created_at >= date_trunc('month', NOW() - interval '1 month')
      AND created_at < date_trunc('month', NOW())
  )::INT;
END;
$$ LANGUAGE plpgsql;

-- Function to get the total count of posts (pins + assets) from the previous month
CREATE OR REPLACE FUNCTION get_total_posts_previous_month()
RETURNS INT AS $$
DECLARE
  pin_count INT;
  asset_count INT;
BEGIN
  SELECT COUNT(*) INTO pin_count
  FROM public.pins
  WHERE created_at >= date_trunc('month', NOW() - interval '1 month')
    AND created_at < date_trunc('month', NOW());

  SELECT COUNT(*) INTO asset_count
  FROM public.assets
  WHERE created_at >= date_trunc('month', NOW() - interval '1 month')
    AND created_at < date_trunc('month', NOW());

  RETURN pin_count + asset_count;
END;
$$ LANGUAGE plpgsql;

-- Function to get the total count of referrals from the previous month
CREATE OR REPLACE FUNCTION get_total_referrals_previous_month()
RETURNS INT AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)
    FROM public.referrals
    WHERE created_at >= date_trunc('month', NOW() - interval '1 month')
      AND created_at < date_trunc('month', NOW())
  )::INT;
END;
$$ LANGUAGE plpgsql;

-- Function to get the total credits used (quotes requested) in the previous month
CREATE OR REPLACE FUNCTION get_total_credits_used_previous_month()
RETURNS INT AS $$
BEGIN
  RETURN (
    SELECT COALESCE(SUM(quotes_requested), 0)
    FROM public.analytics_daily
    WHERE date >= date_trunc('month', NOW() - interval '1 month')
      AND date < date_trunc('month', NOW())
  )::INT;
END;
$$ LANGUAGE plpgsql;

-- Function to get the number of new users grouped by month for chart data
CREATE OR REPLACE FUNCTION get_new_users_per_month()
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_agg(
      jsonb_build_object(
        'x', to_char(month, 'YYYY-MM'),
        'y', user_count
      )
    )
    FROM (
      SELECT
        date_trunc('month', created_at) AS month,
        COUNT(*) AS user_count
      FROM public.users
      GROUP BY month
      ORDER BY month
    ) AS monthly_counts
  );
END;
$$ LANGUAGE plpgsql;