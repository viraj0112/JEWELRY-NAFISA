-- Create function to get similar products from both products and designerproducts tables
CREATE OR REPLACE FUNCTION get_similar_products(
  p_product_type TEXT DEFAULT NULL,
  p_category TEXT DEFAULT NULL,
  p_sub_category TEXT DEFAULT NULL,
  p_limit INT DEFAULT 10,
  p_exclude_id TEXT DEFAULT NULL,
  p_is_designer BOOLEAN DEFAULT NULL
)
RETURNS TABLE (
  id TEXT,
  "Product Title" TEXT,
  Image TEXT,
  Description TEXT,
  "Product Type" TEXT,
  Category TEXT,
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
    -- Query products table (when p_is_designer is false or NULL)
    SELECT 
      p.id::TEXT,
      p."Product Title",
      CASE 
        WHEN p."Image" IS NULL OR array_length(p."Image", 1) IS NULL THEN NULL::TEXT
        WHEN array_length(p."Image", 1) > 0 THEN (p."Image")[1]::TEXT
        ELSE NULL::TEXT
      END as Image,
      p."Description",
      p."Product Type",
      p."Category",
      p."Sub Category",
      p."Metal Type",
      p."Metal Purity",
      p."Plain",
      p."Studded",
      p."Price",
      FALSE as is_designer_product
    FROM products p
    WHERE (p_is_designer IS NULL OR p_is_designer = FALSE)
      AND (p_exclude_id IS NULL OR p.id::TEXT != p_exclude_id)
      AND (
        (p_product_type IS NULL OR p."Product Type" = p_product_type)
        AND (p_category IS NULL OR p."Category" = p_category)
        AND (p_sub_category IS NULL OR p."Sub Category" = p_sub_category)
      )
    
    UNION ALL
    
    -- Query designerproducts table (when p_is_designer is true or NULL)
    SELECT 
      dp.id::TEXT,
      dp."Product Title",
      CASE 
        WHEN dp."Image" IS NULL OR array_length(dp."Image", 1) IS NULL THEN NULL::TEXT
        WHEN array_length(dp."Image", 1) > 0 THEN (dp."Image")[1]::TEXT
        ELSE NULL::TEXT
      END as Image,
      dp."Description",
      dp."Product Type",
      dp."Category",
      dp."Sub Category",
      dp."Metal Type",
      dp."Metal Purity",
      dp."Plain",
      dp."Studded",
      dp."Price",
      TRUE as is_designer_product
    FROM designerproducts dp
    WHERE (p_is_designer IS NULL OR p_is_designer = TRUE)
      AND (p_exclude_id IS NULL OR dp.id::TEXT != p_exclude_id)
      AND (
        (p_product_type IS NULL OR dp."Product Type" = p_product_type)
        AND (p_category IS NULL OR dp."Category" = p_category)
        AND (p_sub_category IS NULL OR dp."Sub Category" = p_sub_category)
      )
  )
  SELECT * FROM combined_results
  ORDER BY random()
  LIMIT p_limit;
END;
$$;

