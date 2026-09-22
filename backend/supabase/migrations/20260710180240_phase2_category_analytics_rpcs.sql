-- ============================================================================
-- PHASE 2c — NEW analytics RPCs (category-based counts)
-- ============================================================================
-- Built on the Phase 1 category_arr column (text[]). "Count by category" means
-- UNNESTing the array so each category value becomes its own row to group on.
--
-- Both functions UNION all three product tables (now symmetric after Phase 1)
-- and take p_table_filter to scope to one catalog: 'all' | 'products' |
-- 'designerproducts' | 'manufacturerproducts'.
--
-- These read category_arr / "Product Type" / "Plain" / "Studded" which all exist
-- during Phase 2. In Phase 3, category_arr is renamed to "Category" -> update the
-- bodies at that time.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- RPC A: product_type_counts_by_category
--   For each category value, how many items of each Product Type.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.product_type_counts_by_category(
  p_table_filter text DEFAULT 'all'
)
RETURNS TABLE (category text, product_type text, item_count bigint)
LANGUAGE sql STABLE AS $$
  WITH all_p AS (
    SELECT category_arr, "Product Type" AS product_type, 'products' AS src
      FROM public.products
    UNION ALL
    SELECT category_arr, "Product Type", 'designerproducts'
      FROM public.designerproducts
    UNION ALL
    SELECT category_arr, "Product Type", 'manufacturerproducts'
      FROM public.manufacturerproducts
  )
  SELECT
    cat AS category,
    COALESCE(product_type, '(unspecified)') AS product_type,
    COUNT(*) AS item_count
  FROM all_p
  CROSS JOIN LATERAL unnest(all_p.category_arr) AS cat
  WHERE (p_table_filter = 'all' OR src = p_table_filter)
  GROUP BY cat, product_type
  ORDER BY cat, item_count DESC;
$$;

-- ----------------------------------------------------------------------------
-- RPC B: plain_studded_counts_by_category
--   For each category value: how many are Plain, how many Studded, and total.
--   Plain   = "Plain" is a non-blank value.
--   Studded = "Studded" array is non-empty.
--   (A row could be both or neither -> counted independently via FILTER.)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.plain_studded_counts_by_category(
  p_table_filter text DEFAULT 'all'
)
RETURNS TABLE (category text, plain_count bigint, studded_count bigint, total_count bigint)
LANGUAGE sql STABLE AS $$
  WITH all_p AS (
    SELECT category_arr, "Plain" AS plain, "Studded" AS studded, 'products' AS src
      FROM public.products
    UNION ALL
    SELECT category_arr, "Plain", "Studded", 'designerproducts'
      FROM public.designerproducts
    UNION ALL
    SELECT category_arr, "Plain", "Studded", 'manufacturerproducts'
      FROM public.manufacturerproducts
  )
  SELECT
    cat AS category,
    COUNT(*) FILTER (WHERE plain IS NOT NULL AND btrim(plain) <> '')          AS plain_count,
    COUNT(*) FILTER (WHERE studded IS NOT NULL AND array_length(studded, 1) > 0) AS studded_count,
    COUNT(*)                                                                    AS total_count
  FROM all_p
  CROSS JOIN LATERAL unnest(all_p.category_arr) AS cat
  WHERE (p_table_filter = 'all' OR src = p_table_filter)
  GROUP BY cat
  ORDER BY total_count DESC, category;
$$;
