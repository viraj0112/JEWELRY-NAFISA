-- Exact product counts per Product Type for the catalog analytics dashboard.
--
-- catalog_hierarchy_counts unnests the text[] "Category" column, so a product
-- listed under N categories appears in N rows. Summing those rows per product
-- type over-counted every multi-category product. This function counts each
-- product once, optionally narrowed to products that sit in at least one of
-- p_categories. Category/product-type normalisation matches
-- catalog_hierarchy_counts so the dashboard's filter values line up.

CREATE OR REPLACE FUNCTION public.product_type_counts(
  p_table_filter text DEFAULT 'all',
  p_categories text[] DEFAULT NULL
)
RETURNS TABLE (
  product_type text,
  item_count bigint
)
LANGUAGE sql
STABLE
AS $$
  WITH catalog AS (
    SELECT p."Product Type" AS product_type, p."Category" AS category_list
    FROM public.products p
    WHERE p_table_filter IN ('all', 'products')

    UNION ALL

    SELECT p."Product Type", p."Category"
    FROM public.designerproducts p
    WHERE p_table_filter IN ('all', 'designerproducts')

    UNION ALL

    SELECT p."Product Type", p."Category"
    FROM public.manufacturerproducts p
    WHERE p_table_filter IN ('all', 'manufacturerproducts')
  )
  SELECT
    COALESCE(NULLIF(btrim(c.product_type), ''), '(unspecified)') AS product_type,
    COUNT(*)::bigint AS item_count
  FROM catalog c
  WHERE p_categories IS NULL
     OR cardinality(p_categories) = 0
     OR EXISTS (
          SELECT 1
          FROM unnest(
            CASE
              WHEN c.category_list IS NULL OR cardinality(c.category_list) = 0
                THEN ARRAY[NULL]::text[]
              ELSE c.category_list
            END
          ) AS categories(category_value)
          WHERE COALESCE(NULLIF(btrim(category_value), ''), 'Uncategorized')
                = ANY (p_categories)
        )
  GROUP BY 1
  ORDER BY 2 DESC;
$$;

GRANT EXECUTE ON FUNCTION public.product_type_counts(text, text[])
  TO anon, authenticated, service_role;
