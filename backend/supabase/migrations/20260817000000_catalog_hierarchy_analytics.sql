-- Catalog analytics hierarchy: Product Type -> Category -> Sub Category.
-- Category is text[] in all catalogs, so it must be expanded before grouping.

ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS "Sub Category" text;

CREATE OR REPLACE FUNCTION public.catalog_hierarchy_counts(
  p_table_filter text DEFAULT 'all'
)
RETURNS TABLE (
  source_table text,
  product_type text,
  category text,
  sub_category text,
  item_count bigint
)
LANGUAGE sql
STABLE
AS $$
  WITH catalog AS (
    SELECT 'products'::text AS source_table,
           p."Product Type" AS product_type,
           p."Category" AS category_list,
           p."Sub Category" AS sub_category
    FROM public.products p
    WHERE p_table_filter IN ('all', 'products')

    UNION ALL

    SELECT 'designerproducts'::text,
           p."Product Type",
           p."Category",
           p."Sub Category"
    FROM public.designerproducts p
    WHERE p_table_filter IN ('all', 'designerproducts')

    UNION ALL

    SELECT 'manufacturerproducts'::text,
           p."Product Type",
           p."Category",
           p."Sub Category"
    FROM public.manufacturerproducts p
    WHERE p_table_filter IN ('all', 'manufacturerproducts')
  ),
  expanded AS (
    SELECT
      c.source_table,
      COALESCE(NULLIF(btrim(c.product_type), ''), '(unspecified)') AS product_type,
      COALESCE(NULLIF(btrim(category_value), ''), 'Uncategorized') AS category,
      COALESCE(NULLIF(btrim(c.sub_category), ''), 'Uncategorized') AS sub_category
    FROM catalog c
    LEFT JOIN LATERAL unnest(
      CASE
        WHEN c.category_list IS NULL OR cardinality(c.category_list) = 0
          THEN ARRAY[NULL]::text[]
        ELSE c.category_list
      END
    ) AS categories(category_value) ON TRUE
  )
  SELECT source_table, product_type, category, sub_category, COUNT(*)::bigint
  FROM expanded
  GROUP BY source_table, product_type, category, sub_category
  ORDER BY category, product_type, sub_category, source_table;
$$;

GRANT EXECUTE ON FUNCTION public.catalog_hierarchy_counts(text)
  TO anon, authenticated, service_role;