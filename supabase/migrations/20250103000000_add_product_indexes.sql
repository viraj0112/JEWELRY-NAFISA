-- Add indexes to optimize product queries and filtering
-- This will significantly improve query performance for filtered product searches

-- Indexes for 'products' table
-- Note: 'products' table does NOT have a 'created_at' column
CREATE INDEX IF NOT EXISTS idx_products_product_type ON products("Product Type");
CREATE INDEX IF NOT EXISTS idx_products_category ON products("Category");
CREATE INDEX IF NOT EXISTS idx_products_category1 ON products("Category1");
CREATE INDEX IF NOT EXISTS idx_products_category2 ON products("Category2");
CREATE INDEX IF NOT EXISTS idx_products_category3 ON products("Category3");
CREATE INDEX IF NOT EXISTS idx_products_sub_category ON products("Sub Category");
CREATE INDEX IF NOT EXISTS idx_products_metal_purity ON products("Metal Purity");
CREATE INDEX IF NOT EXISTS idx_products_plain ON products("Plain");

-- Composite index for common filter combinations
CREATE INDEX IF NOT EXISTS idx_products_type_category ON products("Product Type", "Category");
CREATE INDEX IF NOT EXISTS idx_products_type_metal ON products("Product Type", "Metal Purity");

-- Indexes for 'designerproducts' table
-- Note: 'designerproducts' table HAS a 'created_at' column
CREATE INDEX IF NOT EXISTS idx_designerproducts_product_type ON designerproducts("Product Type");
CREATE INDEX IF NOT EXISTS idx_designerproducts_category ON designerproducts("Category");
CREATE INDEX IF NOT EXISTS idx_designerproducts_category1 ON designerproducts("Category1");
CREATE INDEX IF NOT EXISTS idx_designerproducts_category2 ON designerproducts("Category2");
CREATE INDEX IF NOT EXISTS idx_designerproducts_category3 ON designerproducts("Category3");
CREATE INDEX IF NOT EXISTS idx_designerproducts_sub_category ON designerproducts("Sub Category");
CREATE INDEX IF NOT EXISTS idx_designerproducts_metal_purity ON designerproducts("Metal Purity");
CREATE INDEX IF NOT EXISTS idx_designerproducts_plain ON designerproducts("Plain");
CREATE INDEX IF NOT EXISTS idx_designerproducts_created_at ON designerproducts(created_at DESC);

-- Composite index for common filter combinations
CREATE INDEX IF NOT EXISTS idx_designerproducts_type_category ON designerproducts("Product Type", "Category");
CREATE INDEX IF NOT EXISTS idx_designerproducts_type_metal ON designerproducts("Product Type", "Metal Purity");

-- Note: These indexes will improve query performance significantly
-- but may slightly slow down INSERT/UPDATE operations
-- Monitor performance and adjust as needed

