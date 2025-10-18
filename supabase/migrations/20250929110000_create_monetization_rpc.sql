
CREATE OR REPLACE FUNCTION get_monetization_metrics()
RETURNS jsonb AS $$
DECLARE
  v_total_users INT;
  v_member_count INT;
  v_conversion_rate FLOAT;
BEGIN
  -- Get total user count
  SELECT COUNT(*) INTO v_total_users
  FROM public.users;

  -- Get member count
  SELECT COUNT(*) INTO v_member_count
  FROM public.users
  WHERE is_member = true;

  -- Calculate conversion rate
  IF v_total_users > 0 THEN
    v_conversion_rate := v_member_count::float / v_total_users::float;
  ELSE
    v_conversion_rate := 0.0;
  END IF;

  -- Build the JSON object
  RETURN jsonb_build_object(
    'totalRevenue', 12500,  -- Static: No revenue table
    'subscriptions', v_member_count, -- Dynamic
    'conversionRate', v_conversion_rate, -- Dynamic
    'monthlyRecurringRevenue', 2500 -- Static: No revenue table
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;