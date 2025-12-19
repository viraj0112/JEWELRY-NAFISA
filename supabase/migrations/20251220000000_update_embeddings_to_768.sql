-- Migration to update embedding dimensions from 512 to 768 for Dinov2
-- Dinov2-base produces 768-dimensional embeddings

-- Update embedding columns to support 768 dimensions
ALTER TABLE products ALTER COLUMN embedding TYPE vector(768);
ALTER TABLE designerproducts ALTER COLUMN embedding TYPE vector(768);
ALTER TABLE pins ALTER COLUMN embedding TYPE vector(768);

-- Update search function to use 768 dimensions
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
    products."Product Title" as product_title,
    CASE 
      WHEN products."Image" IS NOT NULL AND jsonb_typeof(products."Image"::jsonb) = 'array' 
      THEN products."Image"->>0
      ELSE products."Image"::text
    END as image,
    products."Price"::numeric as price,
    false as is_designer_product,
    1 - (products.embedding <=> query_embedding) as similarity
  FROM products
  WHERE products.embedding IS NOT NULL
    AND 1 - (products.embedding <=> query_embedding) > match_threshold
  
  UNION ALL
  
  SELECT
    designerproducts.id::text,
    designerproducts."Product Title" as product_title,
    CASE 
      WHEN designerproducts."Image" IS NOT NULL AND jsonb_typeof(designerproducts."Image"::jsonb) = 'array' 
      THEN designerproducts."Image"->>0
      ELSE designerproducts."Image"::text
    END as image,
    designerproducts."Price"::numeric as price,
    true as is_designer_product,
    1 - (designerproducts.embedding <=> query_embedding) as similarity
  FROM designerproducts
  WHERE designerproducts.embedding IS NOT NULL
    AND 1 - (designerproducts.embedding <=> query_embedding) > match_threshold
  
  ORDER BY similarity DESC
  LIMIT match_count;
END;
$$;

