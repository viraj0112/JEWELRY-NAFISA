CREATE OR REPLACE FUNCTION get_all_post_analytics()
RETURNS TABLE(
  asset_id UUID,
  asset_title TEXT,
  asset_type TEXT,
  views INT,
  likes INT,
  saves INT,
  date DATE
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    a.id as asset_id,
    a.title as asset_title,
    'Uploaded' as asset_type,
    ad.views,
    ad.likes,
    ad.saves,
    ad.date
  FROM
    public.analytics_daily ad
  JOIN
    public.assets a ON ad.asset_id = a.id
  UNION ALL
  SELECT
    p.id as asset_id,
    p.title as asset_title,
    'Scraped' as asset_type,
    0 as views,
    p.like_count as likes,
    0 as saves,
    CURRENT_DATE as date
  FROM
    public.pins p
  WHERE
    NOT EXISTS (SELECT 1 FROM public.analytics_daily ad WHERE ad.asset_id = p.id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;