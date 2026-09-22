-- Ensure pgvector extension is available
CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA extensions;

-- Set search path to find the vector type
SET search_path TO public, extensions;

-- Drop the existing function by name without type signature (safe)
DO $$
BEGIN
  DROP FUNCTION IF EXISTS public.search_all_products CASCADE;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Create a function to search for products by image embedding
create or replace function search_all_products(
  query_embedding extensions.vector(512),
  match_threshold float,
  match_count int
)
returns table (
  id text,
  product_title text,
  image text,
  price numeric,
  is_designer_product boolean,
  similarity float
)
language plpgsql
SET search_path = public, extensions
as $$
begin
  return query
  select
    products.id::text,
    products.product_title,
    products.image,
    products.price,
    false as is_designer_product,
    1 - (products.embedding <=> query_embedding) as similarity
  from products
  where 1 - (products.embedding <=> query_embedding) > match_threshold
  
  union all
  
  select
    designerproducts.id::text,
    designerproducts.product_title,
    designerproducts.image,
    designerproducts.price,
    true as is_designer_product,
    1 - (designerproducts.embedding <=> query_embedding) as similarity
  from designerproducts
  where 1 - (designerproducts.embedding <=> query_embedding) > match_threshold
  
  order by similarity desc
  limit match_count;
end;
$$;

-- Reset search path
RESET search_path;
