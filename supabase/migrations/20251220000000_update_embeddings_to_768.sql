-- Migration to update embedding dimensions from 512 to 768 for Dinov2
-- Dinov2-base produces 768-dimensional embeddings

-- Ensure pgvector extension is available
CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA extensions;

-- Set search path to find vector type
SET search_path TO public, extensions;

-- Update embedding columns to support 768 dimensions (only if they exist and have the old type)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'products' AND column_name = 'embedding') THEN
    -- Clear existing embeddings (512-dim can't be cast to 768-dim; they need regeneration)
    UPDATE products SET embedding = NULL;
    ALTER TABLE products ALTER COLUMN embedding TYPE extensions.vector(768) USING NULL;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'designerproducts' AND column_name = 'embedding') THEN
    UPDATE designerproducts SET embedding = NULL;
    ALTER TABLE designerproducts ALTER COLUMN embedding TYPE extensions.vector(768) USING NULL;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'pins' AND column_name = 'embedding') THEN
    UPDATE pins SET embedding = NULL;
    ALTER TABLE pins ALTER COLUMN embedding TYPE extensions.vector(768) USING NULL;
  END IF;
END $$;

-- Update search function to use 768 dimensions
DO $$
BEGIN
  DROP FUNCTION IF EXISTS public.search_all_products CASCADE;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

CREATE OR REPLACE FUNCTION search_all_products(
  query_embedding extensions.vector(768),
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
SET search_path = public, extensions
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

-- Reset search path
RESET search_path;
