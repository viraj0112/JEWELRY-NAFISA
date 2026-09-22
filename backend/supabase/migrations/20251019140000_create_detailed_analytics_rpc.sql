-- In supabase/migrations/20251019140000_create_detailed_analytics_rpc.sql

CREATE OR REPLACE FUNCTION get_user_growth_over_time(
    start_date timestamptz,
    end_date timestamptz
)
RETURNS TABLE(day text, new_users_count bigint) AS $$
BEGIN
    RETURN QUERY
    SELECT
        to_char(date_trunc('day', created_at), 'YYYY-MM-DD') AS day,
        COUNT(id) AS new_users_count
    FROM
        public.users
    WHERE
        created_at >= start_date AND created_at <= end_date
    GROUP BY
        date_trunc('day', created_at)
    ORDER BY
        date_trunc('day', created_at) ASC;
END;
$$ LANGUAGE plpgsql;