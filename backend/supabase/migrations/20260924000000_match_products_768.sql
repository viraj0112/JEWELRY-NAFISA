-- match_products (AI lens / image search) moves to 768-dim embeddings.
--
-- The embedding columns were changed to vector(768) in
-- 20251220000000_update_embeddings_to_768.sql, but match_products still took a
-- vector(512), so every search failed with a dimension mismatch. The
-- ai-image-search service and scripts/populate_embeddings.py now both use
-- CLIP ViT-L/14 (768-dim).
--
-- Also searches manufacturerproducts. Return shape is unchanged (output column
-- stays named "Image" so the ai-image-search caller is untouched).

-- manufacturerproducts was not covered by the 768 migration. Bring it in line
-- (only when it isn't already 768; old embeddings of another size are unusable
-- against 768-dim queries anyway, so they are cleared and regenerated).
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_attribute
    WHERE attrelid = 'public.manufacturerproducts'::regclass
      AND attname = 'embedding'
      AND NOT attisdropped
      AND atttypmod <> 768
  ) THEN
    ALTER TABLE public.manufacturerproducts
      ALTER COLUMN embedding TYPE extensions.vector(768) USING NULL;
  END IF;
END $$;

DROP FUNCTION IF EXISTS public.match_products(extensions.vector, double precision, integer);

CREATE FUNCTION public.match_products(
  query_embedding extensions.vector(768),
  match_threshold float,
  match_count int
)
RETURNS TABLE (
  source text,
  id int,
  "Product Title" text,
  "Image" text[],
  similarity float
)
LANGUAGE sql STABLE
SET search_path = public, extensions
AS $$
  (
    SELECT 'products' AS source, p.id, p."Product Title", p."Images",
           1 - (p.embedding <=> query_embedding) AS similarity
    FROM public.products p
    WHERE p.embedding IS NOT NULL
      AND 1 - (p.embedding <=> query_embedding) >= match_threshold
  )
  UNION ALL
  (
    SELECT 'designerproducts', d.id, d."Product Title", d."Images",
           1 - (d.embedding <=> query_embedding)
    FROM public.designerproducts d
    WHERE d.embedding IS NOT NULL
      AND 1 - (d.embedding <=> query_embedding) >= match_threshold
  )
  UNION ALL
  (
    SELECT 'manufacturerproducts', m.id, m."Product Title", m."Images",
           1 - (m.embedding <=> query_embedding)
    FROM public.manufacturerproducts m
    WHERE m.embedding IS NOT NULL
      AND 1 - (m.embedding <=> query_embedding) >= match_threshold
  )
  ORDER BY similarity DESC
  LIMIT match_count;
$$;
