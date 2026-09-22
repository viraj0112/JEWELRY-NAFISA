-- get_distinct_product_values compared every column with '' ("%I <> ''").
-- Since the Phase 3 unification several catalog columns ("Category",
-- "Metal Color", ...) are text[], and Postgres cannot cast '' to an array:
--   ERROR 22P02 malformed array literal: ""
-- which broke the admin Teams category filter and the scraped/engagement
-- analytics category pickers.
--
-- The function now inspects each table's column type: array columns are
-- unnested, scalar columns are used as-is. It also covers
-- manufacturerproducts, which the old version skipped, and skips any table
-- that doesn't have the column instead of failing.

CREATE OR REPLACE FUNCTION public.get_distinct_product_values(column_name text)
RETURNS SETOF text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  tbl text;
  col_type text;
  parts text[] := ARRAY[]::text[];
BEGIN
  FOREACH tbl IN ARRAY ARRAY['products', 'designerproducts', 'manufacturerproducts']
  LOOP
    SELECT c.data_type
      INTO col_type
      FROM information_schema.columns c
     WHERE c.table_schema = 'public'
       AND c.table_name = tbl
       AND c.column_name = get_distinct_product_values.column_name;

    IF NOT FOUND THEN
      CONTINUE;
    END IF;

    IF col_type = 'ARRAY' THEN
      parts := parts || format(
        'SELECT btrim(v::text) FROM public.%I t CROSS JOIN LATERAL unnest(t.%I) AS u(v)',
        tbl, get_distinct_product_values.column_name);
    ELSE
      parts := parts || format(
        'SELECT btrim(t.%I::text) FROM public.%I t',
        get_distinct_product_values.column_name, tbl);
    END IF;
  END LOOP;

  IF cardinality(parts) = 0 THEN
    RETURN;
  END IF;

  RETURN QUERY EXECUTE
    'SELECT DISTINCT s.v FROM (' || array_to_string(parts, ' UNION ALL ')
    || ') AS s(v) WHERE s.v IS NOT NULL AND s.v <> '''' ORDER BY 1';
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_distinct_product_values(text)
  TO anon, authenticated, service_role;
