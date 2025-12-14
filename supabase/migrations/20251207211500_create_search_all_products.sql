-- Drop the existing function to allow return type change
-- We use both signatures to be safe, as float maps to double precision
DROP FUNCTION IF EXISTS search_all_products(vector, float, int);
DROP FUNCTION IF EXISTS search_all_products(vector, double precision, integer);

-- Create a function to search for products by image embedding
create or replace function search_all_products(
  query_embedding vector(512),
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
