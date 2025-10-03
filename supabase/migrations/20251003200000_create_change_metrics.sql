CREATE OR REPLACE FUNCTION get_total_referrals_previous_month()
RETURNS INT AS $$
BEGIN
    RETURN (
        SELECT COUNT(*)
        FROM referrals
        WHERE created_at < date_trunc('month', current_date)
          AND created_at >= date_trunc('month', current_date) - interval '1 month'
    );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_total_credits_used_previous_month()
RETURNS INT AS $$
BEGIN
    RETURN (
        SELECT SUM(quotes_requested)
        FROM analytics_daily
        WHERE date < date_trunc('month', current_date)
          AND date >= date_trunc('month', current_date) - interval '1 month'
    );
END;
$$ LANGUAGE plpgsql;