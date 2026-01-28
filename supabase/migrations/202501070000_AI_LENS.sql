drop function if exists match_products(
  vector,
  double precision,
  integer
);


create or replace function match_products(
  query_embedding vector(512),
  match_threshold float,
  match_count int
)
returns table (
  source text,
  id int,
  "Product Title" text,
  "Image" text[],
  similarity float
)
language sql
stable
as $$
  (
    select
      'products' as source,
      p.id,
      p."Product Title",
      p."Image",
      1 - (p.embedding <=> query_embedding) as similarity
    from public.products p
    where p.embedding is not null
      and 1 - (p.embedding <=> query_embedding) >= match_threshold
  )

  union all

  (
    select
      'designerproducts' as source,
      d.id,
      d."Product Title",
      d."Image",
      1 - (d.embedding <=> query_embedding) as similarity
    from public.designerproducts d
    where d.embedding is not null
      and 1 - (d.embedding <=> query_embedding) >= match_threshold
  )

  order by similarity desc
  limit match_count;
$$;
