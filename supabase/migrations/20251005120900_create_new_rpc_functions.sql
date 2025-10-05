-- Gets the credit history for a specific user
CREATE OR REPLACE FUNCTION get_user_credit_history(p_user_id UUID)
RETURNS TABLE(entry_date DATE, credits_added INT, credits_spent INT) AS $$
BEGIN
    RETURN QUERY
    SELECT
        date_trunc('day', created_at)::DATE AS entry_date,
        SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END) AS credits_added,
        SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END) AS credits_spent
    FROM
        public.credit_transactions
    WHERE
        user_id = p_user_id
    GROUP BY
        entry_date
    ORDER BY
        entry_date DESC;
END;
$$ LANGUAGE plpgsql;

-- Gets the referral tree for a user
CREATE OR REPLACE FUNCTION get_referral_tree(p_user_id UUID)
RETURNS TABLE(level INT, user_id UUID, username TEXT, referred_by UUID) AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE referral_hierarchy AS (
        SELECT
            0 AS level,
            u.id AS user_id,
            u.username,
            u.referred_by
        FROM
            public.users u
        WHERE
            u.id = p_user_id

        UNION ALL

        SELECT
            rh.level + 1,
            u.id,
            u.username,
            u.referred_by
        FROM
            public.users u
        JOIN
            referral_hierarchy rh ON u.referred_by = rh.user_id
    )
    SELECT
        rh.level,
        rh.user_id,
        rh.username,
        rh.referred_by
    FROM
        referral_hierarchy rh;
END;
$$ LANGUAGE plpgsql;

-- Gets analytics for a specific creator
CREATE OR REPLACE FUNCTION get_creator_dashboard(p_creator_id UUID)
RETURNS JSONB AS $$
DECLARE
    total_works_uploaded INT;
    top_posts JSONB;
    total_unlocks INT;
    total_saves INT;
BEGIN
    SELECT COUNT(*) INTO total_works_uploaded
    FROM public.assets
    WHERE owner_id = p_creator_id;

    SELECT jsonb_agg(top_assets) INTO top_posts
    FROM (
        SELECT
            a.title,
            ad.views,
            ad.likes,
            ad.saves
        FROM public.assets a
        JOIN public.analytics_daily ad ON a.id = ad.asset_id
        WHERE a.owner_id = p_creator_id
        ORDER BY ad.views DESC
        LIMIT 5
    ) AS top_assets;

    SELECT SUM(ad.quotes_requested), SUM(ad.saves) INTO total_unlocks, total_saves
    FROM public.analytics_daily ad
    JOIN public.assets a ON ad.asset_id = a.id
    WHERE a.owner_id = p_creator_id;

    RETURN jsonb_build_object(
        'total_works_uploaded', total_works_uploaded,
        'top_posts', top_posts,
        'total_unlocks', total_unlocks,
        'total_saves', total_saves
    );
END;
$$ LANGUAGE plpgsql;