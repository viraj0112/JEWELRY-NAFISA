CREATE OR REPLACE FUNCTION get_monetization_metrics()
RETURNS jsonb AS $$
BEGIN
  RETURN jsonb_build_object(
    'totalRevenue', 12500,
    'subscriptions', 450,
    'conversionRate', 0.15,
    'monthlyRecurringRevenue', 2500
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;