-- ============================================================================
-- PHASE 1 — EXPAND: unify product schemas (ADDITIVE ONLY, nothing dropped)
-- ============================================================================
-- Adds new unified columns alongside the old ones and backfills them.
-- No column is dropped, renamed, or retyped in place -> old app code keeps working.
-- Fully reversible: DROP the added columns to undo.
--
-- New staging columns (renamed to final names in Phase 3, to avoid name collisions
-- with existing "Images" (text) and "Metal Color" (text) columns):
--   images_arr      text[]  <- merge of "Image" (array) + "Images" (text)
--   metal_color_arr text[]  <- retype of "Metal Color" (text), blanks stripped
--   category_arr    text[]  <- dedup merge of "Category" + "Category1/2/3"
-- Plus: created_at on products; "Metal Weight" on designer/manufacturer.
--
-- Decisions baked in:
--   * images_arr order = array items first, then the single text item.
--   * category_arr order = "Category" first, then 1,2,3; deduped; nulls/blanks stripped.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Helper: dedup a text[] while PRESERVING first-seen order, dropping null/blank.
-- (Plain SELECT DISTINCT / array_agg(DISTINCT) does NOT preserve order, so we
--  use WITH ORDINALITY to remember position, then keep the first occurrence.)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.array_dedup_ordered(arr text[])
RETURNS text[]
LANGUAGE sql IMMUTABLE AS $$
  SELECT COALESCE(
    array_agg(val ORDER BY first_pos),
    ARRAY[]::text[]
  )
  FROM (
    SELECT val, MIN(ord) AS first_pos
    FROM unnest(arr) WITH ORDINALITY AS t(val, ord)
    WHERE val IS NOT NULL AND btrim(val) <> ''
    GROUP BY val
  ) d;
$$;

-- ============================================================================
-- TABLE: products
-- ============================================================================
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS images_arr      text[];
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS metal_color_arr text[];
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS category_arr    text[];
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS created_at      timestamptz DEFAULT now();

-- images_arr: array items first, then the single text image (if any), blanks stripped.
UPDATE public.products
SET images_arr = public.array_dedup_ordered(
  COALESCE("Image", ARRAY[]::text[])
  || CASE WHEN "Images" IS NOT NULL AND btrim("Images") <> '' THEN ARRAY["Images"] ELSE ARRAY[]::text[] END
);

-- metal_color_arr: single text -> one-element array, blank/null -> empty array.
UPDATE public.products
SET metal_color_arr = public.array_dedup_ordered(ARRAY["Metal Color"]);

-- category_arr: "Category" first, then Category1/2/3; deduped; nulls/blanks stripped.
UPDATE public.products
SET category_arr = public.array_dedup_ordered(
  ARRAY["Category", "Category1", "Category2", "Category3"]
);

-- ============================================================================
-- TABLE: designerproducts  (has "Image" array only; no "Images" text column)
-- ============================================================================
ALTER TABLE public.designerproducts ADD COLUMN IF NOT EXISTS images_arr      text[];
ALTER TABLE public.designerproducts ADD COLUMN IF NOT EXISTS metal_color_arr text[];
ALTER TABLE public.designerproducts ADD COLUMN IF NOT EXISTS category_arr    text[];
ALTER TABLE public.designerproducts ADD COLUMN IF NOT EXISTS "Metal Weight"  text;

UPDATE public.designerproducts
SET images_arr = public.array_dedup_ordered(COALESCE("Image", ARRAY[]::text[]));

UPDATE public.designerproducts
SET metal_color_arr = public.array_dedup_ordered(ARRAY["Metal Color"]);

UPDATE public.designerproducts
SET category_arr = public.array_dedup_ordered(
  ARRAY["Category", "Category1", "Category2", "Category3"]
);

-- Backfill "Metal Weight" from "Gold Weight" where empty.
UPDATE public.designerproducts
SET "Metal Weight" = "Gold Weight"
WHERE ("Metal Weight" IS NULL OR btrim("Metal Weight") = '')
  AND "Gold Weight" IS NOT NULL;

-- ============================================================================
-- TABLE: manufacturerproducts  (has "Image" array only; no "Images" text column)
-- ============================================================================
ALTER TABLE public.manufacturerproducts ADD COLUMN IF NOT EXISTS images_arr      text[];
ALTER TABLE public.manufacturerproducts ADD COLUMN IF NOT EXISTS metal_color_arr text[];
ALTER TABLE public.manufacturerproducts ADD COLUMN IF NOT EXISTS category_arr    text[];
ALTER TABLE public.manufacturerproducts ADD COLUMN IF NOT EXISTS "Metal Weight"  text;

UPDATE public.manufacturerproducts
SET images_arr = public.array_dedup_ordered(COALESCE("Image", ARRAY[]::text[]));

UPDATE public.manufacturerproducts
SET metal_color_arr = public.array_dedup_ordered(ARRAY["Metal Color"]);

UPDATE public.manufacturerproducts
SET category_arr = public.array_dedup_ordered(
  ARRAY["Category", "Category1", "Category2", "Category3"]
);

UPDATE public.manufacturerproducts
SET "Metal Weight" = "Gold Weight"
WHERE ("Metal Weight" IS NULL OR btrim("Metal Weight") = '')
  AND "Gold Weight" IS NOT NULL;

-- ============================================================================
-- INDEXES: GIN on the new array columns so array filtering / unnest stays fast.
-- (GIN = Generalized Inverted Index; the standard index type for array & jsonb
--  containment queries like  category_arr @> ARRAY['Rings'].)
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_products_category_arr             ON public.products             USING gin (category_arr);
CREATE INDEX IF NOT EXISTS idx_designerproducts_category_arr     ON public.designerproducts     USING gin (category_arr);
CREATE INDEX IF NOT EXISTS idx_manufacturerproducts_category_arr ON public.manufacturerproducts USING gin (category_arr);
