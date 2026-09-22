
CREATE OR REPLACE FUNCTION get_distinct_category_values()
RETURNS TABLE(value TEXT) AS $$
BEGIN
  RETURN QUERY
  SELECT DISTINCT cat_value::TEXT
  FROM (
    SELECT "Category" AS cat_value FROM products WHERE "Category" IS NOT NULL AND "Category"::TEXT != ''
    UNION ALL
    SELECT "Category1" AS cat_value FROM products WHERE "Category1" IS NOT NULL AND "Category1"::TEXT != ''
    UNION ALL
    SELECT "Category2" AS cat_value FROM products WHERE "Category2" IS NOT NULL AND "Category2"::TEXT != ''
    UNION ALL
    SELECT "Category3" AS cat_value FROM products WHERE "Category3" IS NOT NULL AND "Category3"::TEXT != ''
    UNION ALL
    SELECT "Category" AS cat_value FROM designerproducts WHERE "Category" IS NOT NULL AND "Category"::TEXT != ''
    UNION ALL
    SELECT "Category1" AS cat_value FROM designerproducts WHERE "Category1" IS NOT NULL AND "Category1"::TEXT != ''
    UNION ALL
    SELECT "Category2" AS cat_value FROM designerproducts WHERE "Category2" IS NOT NULL AND "Category2"::TEXT != ''
    UNION ALL
    SELECT "Category3" AS cat_value FROM designerproducts WHERE "Category3" IS NOT NULL AND "Category3"::TEXT != ''
  ) AS all_categories
  WHERE cat_value IS NOT NULL AND cat_value::TEXT != ''
  ORDER BY cat_value;
END;
$$ LANGUAGE plpgsql;


