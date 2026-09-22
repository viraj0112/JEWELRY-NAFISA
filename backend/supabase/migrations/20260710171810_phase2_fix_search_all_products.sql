-- ============================================================================
-- PHASE 2a — FIX: search_all_products (currently broken in production)
-- ============================================================================
-- BUG (confirmed by direct local test): the live version casts the "Image"
-- column (a Postgres text[] ARRAY) directly to jsonb:
--     jsonb_typeof(products."Image"::jsonb)
-- Postgres does NOT support a direct text[] -> jsonb cast. Every call to this
-- function throws:  ERROR: cannot cast type text[] to jsonb
-- This function is unusable in production as-is (likely "similar by image"
-- search has been silently failing).
--
-- FIX: use the Phase 1 "images_arr" column (a clean text[]) and just take its
-- first element directly with array indexing -- no jsonb detour needed at all.
-- ============================================================================

DROP FUNCTION IF EXISTS search_all_products(vector, float, int);
DROP FUNCTION IF EXISTS search_all_products(vector, double precision, integer);

CREATE OR REPLACE FUNCTION search_all_products(
  query_embedding vector(768),
  match_threshold float,
  match_count int
)
RETURNS TABLE (
  id text,
  product_title text,
  image text,
  price numeric,
  is_designer_product boolean,
  similarity float
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    products.id::text,
    products."Product Title" AS product_title,
    (products.images_arr)[1] AS image,           -- first element, NULL if array empty
    NULLIF(products."Price", '')::numeric AS price,
    false AS is_designer_product,
    1 - (products.embedding <=> query_embedding) AS similarity
  FROM products
  WHERE products.embedding IS NOT NULL
    AND 1 - (products.embedding <=> query_embedding) > match_threshold

  UNION ALL

  SELECT
    designerproducts.id::text,
    designerproducts."Product Title" AS product_title,
    (designerproducts.images_arr)[1] AS image,
    NULLIF(designerproducts."Price", '')::numeric AS price,
    true AS is_designer_product,
    1 - (designerproducts.embedding <=> query_embedding) AS similarity
  FROM designerproducts
  WHERE designerproducts.embedding IS NOT NULL
    AND 1 - (designerproducts.embedding <=> query_embedding) > match_threshold

  ORDER BY similarity DESC
  LIMIT match_count;
END;
$$;
