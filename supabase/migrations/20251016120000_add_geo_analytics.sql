-- Function to get view counts by country for a specific designer
CREATE OR REPLACE FUNCTION get_views_by_country(designer_id_param UUID)
RETURNS TABLE(country TEXT, view_count BIGINT) AS $$
BEGIN
  RETURN QUERY
  SELECT
    v.country,
    COUNT(v.id) AS view_count
  FROM
    public.views v
  INNER JOIN
    public.designerproducts dp ON v.product_id = dp.id
  WHERE
    dp.designer_id = designer_id_param
    AND v.country IS NOT NULL
  GROUP BY
    v.country
  ORDER BY
    view_count DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to get performance metrics by category for a specific designer
CREATE OR REPLACE FUNCTION get_category_performance(designer_id_param UUID)
RETURNS TABLE(
  category TEXT,
  total_views BIGINT,
  total_likes BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    dp.category,
    COUNT(DISTINCT v.id) AS total_views,
    COUNT(DISTINCT l.id) AS total_likes
  FROM
    public.designerproducts dp
  LEFT JOIN
    public.views v ON dp.id = v.product_id
  LEFT JOIN
    public.likes l ON dp.id = l.product_id
  WHERE
    dp.designer_id = designer_id_param
  GROUP BY
    dp.category;
END;
$$ LANGUAGE plpgsql;