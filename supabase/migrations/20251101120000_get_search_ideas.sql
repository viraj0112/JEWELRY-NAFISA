CREATE OR REPLACE FUNCTION get_initial_search_ideas(limit_count INT)
RETURNS SETOF TEXT AS $$
BEGIN
  RETURN QUERY
  (
    SELECT DISTINCT "Category" FROM public.products
    WHERE "Category" IS NOT NULL AND "Category" <> ''
    UNION
    SELECT DISTINCT "Product Type" FROM public.products
    WHERE "Product Type" IS NOT NULL AND "Product Type" <> ''
    UNION
    SELECT DISTINCT "Theme" FROM public.products
    WHERE "Theme" IS NOT NULL AND "Theme" <> ''
    UNION
    SELECT DISTINCT unnest("Product Tags") FROM public.products
    WHERE "Product Tags" IS NOT NULL
  )
  ORDER BY random() 
  LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;