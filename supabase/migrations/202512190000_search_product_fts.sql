-- Create a function for full-text search across both products and designerproducts tables
CREATE OR REPLACE FUNCTION search_products_fts(
  search_query TEXT,
  limit_count INT DEFAULT 50
)
RETURNS TABLE (
  id TEXT,
  "Product Title" TEXT,
  Image TEXT,
  Description TEXT,
  "Product Type" TEXT,
  Category TEXT,
  Category1 TEXT,
  Category2 TEXT,
  Category3 TEXT,
  "Sub Category" TEXT,
  "Metal Type" TEXT,
  "Metal Purity" TEXT,
  Plain TEXT,
  Studded TEXT[],
  Price TEXT,
  is_designer_product BOOLEAN
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH combined_results AS (
    -- Search in products table
    SELECT 
      p.id::TEXT,
      p."Product Title",
      -- Properly extract image from array (Image is ARRAY type in both tables)
      CASE 
        WHEN p."Image" IS NULL OR array_length(p."Image", 1) IS NULL THEN NULL::TEXT
        WHEN array_length(p."Image", 1) > 0 THEN (p."Image")[1]::TEXT
        ELSE NULL::TEXT
      END as Image,
      p."Description",
      p."Product Type",
      p."Category",
      p."Category1",
      p."Category2",
      p."Category3",
      p."Sub Category",
      p."Metal Type",
      p."Metal Purity",
      p."Plain",
      p."Studded",
      p."Price",
      FALSE as is_designer_product,
      -- Add relevance score for ordering (title matches first)
      CASE 
        WHEN p."Product Title" ILIKE '%' || search_query || '%' THEN 1
        WHEN p."Product Type" ILIKE '%' || search_query || '%' THEN 2
        WHEN p."Category" ILIKE '%' || search_query || '%' OR 
             p."Category1" ILIKE '%' || search_query || '%' OR
             p."Category2" ILIKE '%' || search_query || '%' OR
             p."Category3" ILIKE '%' || search_query || '%' THEN 3
        ELSE 4
      END as relevance
    FROM products p
    WHERE 
      p."Product Title" ILIKE '%' || search_query || '%'
      OR p."Description" ILIKE '%' || search_query || '%'
      OR p."Product Type" ILIKE '%' || search_query || '%'
      OR p."Category" ILIKE '%' || search_query || '%'
      OR p."Category1" ILIKE '%' || search_query || '%'
      OR p."Category2" ILIKE '%' || search_query || '%'
      OR p."Category3" ILIKE '%' || search_query || '%'
    
    UNION ALL
    
    -- Search in designerproducts table
    SELECT 
      dp.id::TEXT,
      dp."Product Title",
      -- Properly extract image from array (Image is ARRAY type in both tables)
      CASE 
        WHEN dp."Image" IS NULL OR array_length(dp."Image", 1) IS NULL THEN NULL::TEXT
        WHEN array_length(dp."Image", 1) > 0 THEN (dp."Image")[1]::TEXT
        ELSE NULL::TEXT
      END as Image,
      dp."Description",
      dp."Product Type",
      dp."Category",
      dp."Category1",
      dp."Category2",
      dp."Category3",
      dp."Sub Category",
      dp."Metal Type",
      dp."Metal Purity",
      dp."Plain",
      dp."Studded",
      dp."Price",
      TRUE as is_designer_product,
      -- Add relevance score for ordering (title matches first)
      CASE 
        WHEN dp."Product Title" ILIKE '%' || search_query || '%' THEN 1
        WHEN dp."Product Type" ILIKE '%' || search_query || '%' THEN 2
        WHEN dp."Category" ILIKE '%' || search_query || '%' OR 
             dp."Category1" ILIKE '%' || search_query || '%' OR
             dp."Category2" ILIKE '%' || search_query || '%' OR
             dp."Category3" ILIKE '%' || search_query || '%' THEN 3
        ELSE 4
      END as relevance
    FROM designerproducts dp
    WHERE 
      dp."Product Title" ILIKE '%' || search_query || '%'
      OR dp."Description" ILIKE '%' || search_query || '%'
      OR dp."Product Type" ILIKE '%' || search_query || '%'
      OR dp."Category" ILIKE '%' || search_query || '%'
      OR dp."Category1" ILIKE '%' || search_query || '%'
      OR dp."Category2" ILIKE '%' || search_query || '%'
      OR dp."Category3" ILIKE '%' || search_query || '%'
  )
  SELECT 
    cr.id,
    cr."Product Title",
    cr.Image,
    cr."Description",
    cr."Product Type",
    cr."Category",
    cr."Category1",
    cr."Category2",
    cr."Category3",
    cr."Sub Category",
    cr."Metal Type",
    cr."Metal Purity",
    cr."Plain",
    cr."Studded",
    cr."Price",
    cr.is_designer_product
  FROM combined_results cr
  ORDER BY cr.relevance, cr."Product Title"
  LIMIT limit_count;
END;
$$;