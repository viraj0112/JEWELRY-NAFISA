-- ============================================================================
-- PHASE 3 — CONTRACT: unify product schemas (DESTRUCTIVE — read before running)
-- ============================================================================
-- Drops the legacy columns, renames the Phase 1 staging columns to their final
-- names, and rewrites every function that referenced the old shape.
--
--   Drop   : "Image", "Images"(text, products only), "Gold Weight",
--            "Category"(scalar), "Category1/2/3", "Collection Name",
--            "Design Type", "Art Form", "Net Weight"/"NET WEIGHT",
--            "Metal Color"(scalar), price_as_of_date
--   Rename : images_arr -> "Images", metal_color_arr -> "Metal Color",
--            category_arr -> "Category"   (all text[])
--
-- PRECONDITIONS (do NOT run otherwise):
--   1. Take an explicit DB snapshot and record its identifier in the deploy log.
--   2. The coordinated Flutter release (unified column names + new
--      get_similar_products(p_categories) call) is built and ready to deploy
--      in the same maintenance window.
--   3. The Mandatory Gate integrity queries returned 0 (this migration also
--      re-runs them as hard aborts after its own backfill catch-up).
--
-- Supabase CLI runs each migration file in ONE transaction: any failure below
-- (including the RAISE EXCEPTION gates) rolls back the whole migration.
-- ============================================================================


-- ============================================================================
-- 1. BACKFILL CATCH-UP (idempotent)
-- ----------------------------------------------------------------------------
-- Phase 1's backfill ran once; rows written by OLD writers since then may hold
-- values only in the legacy columns. Re-merge legacy values into the staging
-- arrays before dropping the legacy columns, so nothing is lost. Existing
-- array content is kept first (order-preserving dedup via array_dedup_ordered).
-- "Metal Color" scalars shaped like '{A, B}' (stringified arrays; see the
-- 20260712074732 fix) are split into real elements, not wrapped whole.
-- ============================================================================

UPDATE public.products SET
  images_arr = public.array_dedup_ordered(
    COALESCE(images_arr, '{}'::text[])
    || COALESCE("Image", '{}'::text[])
    || CASE WHEN "Images" IS NOT NULL AND btrim("Images") <> ''
            THEN ARRAY["Images"] ELSE '{}'::text[] END),
  metal_color_arr = public.array_dedup_ordered(
    COALESCE(metal_color_arr, '{}'::text[])
    || CASE
         WHEN "Metal Color" IS NULL THEN '{}'::text[]
         WHEN "Metal Color" LIKE '{%}' THEN
           ARRAY(SELECT btrim(e)
                 FROM unnest(string_to_array(trim(both '{}' from "Metal Color"), ',')) AS e)
         ELSE ARRAY["Metal Color"]
       END),
  category_arr = public.array_dedup_ordered(
    COALESCE(category_arr, '{}'::text[])
    || ARRAY["Category", "Category1", "Category2", "Category3"]);

UPDATE public.designerproducts SET
  images_arr = public.array_dedup_ordered(
    COALESCE(images_arr, '{}'::text[]) || COALESCE("Image", '{}'::text[])),
  metal_color_arr = public.array_dedup_ordered(
    COALESCE(metal_color_arr, '{}'::text[])
    || CASE
         WHEN "Metal Color" IS NULL THEN '{}'::text[]
         WHEN "Metal Color" LIKE '{%}' THEN
           ARRAY(SELECT btrim(e)
                 FROM unnest(string_to_array(trim(both '{}' from "Metal Color"), ',')) AS e)
         ELSE ARRAY["Metal Color"]
       END),
  category_arr = public.array_dedup_ordered(
    COALESCE(category_arr, '{}'::text[])
    || ARRAY["Category", "Category1", "Category2", "Category3"]);

UPDATE public.manufacturerproducts SET
  images_arr = public.array_dedup_ordered(
    COALESCE(images_arr, '{}'::text[]) || COALESCE("Image", '{}'::text[])),
  metal_color_arr = public.array_dedup_ordered(
    COALESCE(metal_color_arr, '{}'::text[])
    || CASE
         WHEN "Metal Color" IS NULL THEN '{}'::text[]
         WHEN "Metal Color" LIKE '{%}' THEN
           ARRAY(SELECT btrim(e)
                 FROM unnest(string_to_array(trim(both '{}' from "Metal Color"), ',')) AS e)
         ELSE ARRAY["Metal Color"]
       END),
  category_arr = public.array_dedup_ordered(
    COALESCE(category_arr, '{}'::text[])
    || ARRAY["Category", "Category1", "Category2", "Category3"]);


-- ============================================================================
-- 2. INTEGRITY GATE (hard abort -> transaction rollback if any count > 0)
-- ----------------------------------------------------------------------------
-- After the catch-up above these must be 0 by construction; this is the
-- last-line defense against an unexpected data shape.
-- ============================================================================
DO $$
DECLARE
  n bigint;
BEGIN
  SELECT count(*) INTO n FROM public.products
  WHERE (("Image" IS NOT NULL AND array_length("Image",1) > 0)
         OR ("Images" IS NOT NULL AND btrim("Images") <> ''))
    AND (images_arr IS NULL OR array_length(images_arr,1) IS NULL);
  IF n > 0 THEN RAISE EXCEPTION 'Phase 3 gate: % products rows would lose image data', n; END IF;

  SELECT count(*) INTO n FROM public.products
  WHERE (btrim(coalesce("Category",''))||btrim(coalesce("Category1",''))
         ||btrim(coalesce("Category2",''))||btrim(coalesce("Category3",''))) <> ''
    AND (category_arr IS NULL OR array_length(category_arr,1) IS NULL);
  IF n > 0 THEN RAISE EXCEPTION 'Phase 3 gate: % products rows would lose category data', n; END IF;

  SELECT count(*) INTO n FROM public.products
  WHERE "Metal Color" IS NOT NULL AND btrim("Metal Color") <> ''
    AND (metal_color_arr IS NULL OR array_length(metal_color_arr,1) IS NULL);
  IF n > 0 THEN RAISE EXCEPTION 'Phase 3 gate: % products rows would lose metal color data', n; END IF;

  SELECT count(*) INTO n FROM public.designerproducts
  WHERE ("Image" IS NOT NULL AND array_length("Image",1) > 0)
    AND (images_arr IS NULL OR array_length(images_arr,1) IS NULL);
  IF n > 0 THEN RAISE EXCEPTION 'Phase 3 gate: % designerproducts rows would lose image data', n; END IF;

  SELECT count(*) INTO n FROM public.designerproducts
  WHERE (btrim(coalesce("Category",''))||btrim(coalesce("Category1",''))
         ||btrim(coalesce("Category2",''))||btrim(coalesce("Category3",''))) <> ''
    AND (category_arr IS NULL OR array_length(category_arr,1) IS NULL);
  IF n > 0 THEN RAISE EXCEPTION 'Phase 3 gate: % designerproducts rows would lose category data', n; END IF;

  SELECT count(*) INTO n FROM public.designerproducts
  WHERE "Metal Color" IS NOT NULL AND btrim("Metal Color") <> ''
    AND (metal_color_arr IS NULL OR array_length(metal_color_arr,1) IS NULL);
  IF n > 0 THEN RAISE EXCEPTION 'Phase 3 gate: % designerproducts rows would lose metal color data', n; END IF;

  SELECT count(*) INTO n FROM public.manufacturerproducts
  WHERE ("Image" IS NOT NULL AND array_length("Image",1) > 0)
    AND (images_arr IS NULL OR array_length(images_arr,1) IS NULL);
  IF n > 0 THEN RAISE EXCEPTION 'Phase 3 gate: % manufacturerproducts rows would lose image data', n; END IF;

  SELECT count(*) INTO n FROM public.manufacturerproducts
  WHERE (btrim(coalesce("Category",''))||btrim(coalesce("Category1",''))
         ||btrim(coalesce("Category2",''))||btrim(coalesce("Category3",''))) <> ''
    AND (category_arr IS NULL OR array_length(category_arr,1) IS NULL);
  IF n > 0 THEN RAISE EXCEPTION 'Phase 3 gate: % manufacturerproducts rows would lose category data', n; END IF;

  SELECT count(*) INTO n FROM public.manufacturerproducts
  WHERE "Metal Color" IS NOT NULL AND btrim("Metal Color") <> ''
    AND (metal_color_arr IS NULL OR array_length(metal_color_arr,1) IS NULL);
  IF n > 0 THEN RAISE EXCEPTION 'Phase 3 gate: % manufacturerproducts rows would lose metal color data', n; END IF;
END $$;


-- ============================================================================
-- 3. DROP FUNCTIONS THAT REFERENCE THE OLD SHAPE
-- ----------------------------------------------------------------------------
-- All are recreated in section 6 against the new shape, except the three
-- get_similar_products overloads below the live one — those are untracked
-- prod-drift artifacts with no caller (verified: only the 9-arg signature is
-- called from jewelry_service.dart; no edge function references any of them)
-- and are dropped permanently as cleanup.
-- NOT touched: get_category_performance(uuid) — it references columns that
-- have never existed (lowercase dp.category, dp.designer_id, v.product_id),
-- i.e. it is already broken and unreferenced; out of Phase 3 scope.
-- ============================================================================
DROP FUNCTION IF EXISTS public.get_similar_products(text, integer, text);
DROP FUNCTION IF EXISTS public.get_similar_products(text, text, text, integer, text);
DROP FUNCTION IF EXISTS public.get_similar_products(text, text, text, integer, text, boolean);
DROP FUNCTION IF EXISTS public.get_similar_products(text, text, text, text, text, text, integer, text, boolean);
DROP FUNCTION IF EXISTS public.search_inventory_with_metrics(text, text, int, int, int, int, text, timestamptz, timestamptz, int);
DROP FUNCTION IF EXISTS public.get_distinct_category_values();
DROP FUNCTION IF EXISTS public.get_category_performance_analytics();
DROP FUNCTION IF EXISTS public.get_top_content_analytics(integer);
DROP FUNCTION IF EXISTS public.match_products(extensions.vector, double precision, integer);
DROP FUNCTION IF EXISTS public.search_products_fts(text, integer);
DROP FUNCTION IF EXISTS public.search_all_products(extensions.vector, double precision, integer);
DROP FUNCTION IF EXISTS public.get_filtered_scraped_posts(text, text, text);
DROP FUNCTION IF EXISTS public.get_scraped_posts_with_metrics();
DROP FUNCTION IF EXISTS public.get_initial_search_ideas(integer);
DROP FUNCTION IF EXISTS public.get_category_distribution();
DROP FUNCTION IF EXISTS public.product_type_counts_by_category(text);
DROP FUNCTION IF EXISTS public.plain_studded_counts_by_category(text);


-- ============================================================================
-- 4. DROP LEGACY COLUMNS
-- ----------------------------------------------------------------------------
-- The scalar "Category" and "Metal Color" drops are required for the renames
-- below (their names are being taken over by the array columns); their data
-- was merged into the arrays in Phase 1 + section 1 above.
-- Indexes on dropped columns are dropped automatically by Postgres.
-- ============================================================================
ALTER TABLE public.products
  DROP COLUMN IF EXISTS "Image",
  DROP COLUMN IF EXISTS "Images",
  DROP COLUMN IF EXISTS "Gold Weight",
  DROP COLUMN IF EXISTS "Category",
  DROP COLUMN IF EXISTS "Category1",
  DROP COLUMN IF EXISTS "Category2",
  DROP COLUMN IF EXISTS "Category3",
  DROP COLUMN IF EXISTS "Collection Name",
  DROP COLUMN IF EXISTS "Design Type",
  DROP COLUMN IF EXISTS "Art Form",
  DROP COLUMN IF EXISTS "Net Weight",
  DROP COLUMN IF EXISTS "NET WEIGHT",
  DROP COLUMN IF EXISTS "Metal Color",
  DROP COLUMN IF EXISTS price_as_of_date;

ALTER TABLE public.designerproducts
  DROP COLUMN IF EXISTS "Image",
  DROP COLUMN IF EXISTS "Gold Weight",
  DROP COLUMN IF EXISTS "Category",
  DROP COLUMN IF EXISTS "Category1",
  DROP COLUMN IF EXISTS "Category2",
  DROP COLUMN IF EXISTS "Category3",
  DROP COLUMN IF EXISTS "Collection Name",
  DROP COLUMN IF EXISTS "Design Type",
  DROP COLUMN IF EXISTS "Art Form",
  DROP COLUMN IF EXISTS "Net Weight",
  DROP COLUMN IF EXISTS "NET WEIGHT",
  DROP COLUMN IF EXISTS "Metal Color",
  DROP COLUMN IF EXISTS price_as_of_date;

ALTER TABLE public.manufacturerproducts
  DROP COLUMN IF EXISTS "Image",
  DROP COLUMN IF EXISTS "Gold Weight",
  DROP COLUMN IF EXISTS "Category",
  DROP COLUMN IF EXISTS "Category1",
  DROP COLUMN IF EXISTS "Category2",
  DROP COLUMN IF EXISTS "Category3",
  DROP COLUMN IF EXISTS "Collection Name",
  DROP COLUMN IF EXISTS "Design Type",
  DROP COLUMN IF EXISTS "Art Form",
  DROP COLUMN IF EXISTS "Net Weight",
  DROP COLUMN IF EXISTS "NET WEIGHT",
  DROP COLUMN IF EXISTS "Metal Color",
  DROP COLUMN IF EXISTS price_as_of_date;


-- ============================================================================
-- 5. RENAME STAGING COLUMNS TO FINAL NAMES + INDEX HOUSEKEEPING
-- ============================================================================
ALTER TABLE public.products             RENAME COLUMN images_arr      TO "Images";
ALTER TABLE public.products             RENAME COLUMN metal_color_arr TO "Metal Color";
ALTER TABLE public.products             RENAME COLUMN category_arr    TO "Category";
ALTER TABLE public.designerproducts     RENAME COLUMN images_arr      TO "Images";
ALTER TABLE public.designerproducts     RENAME COLUMN metal_color_arr TO "Metal Color";
ALTER TABLE public.designerproducts     RENAME COLUMN category_arr    TO "Category";
ALTER TABLE public.manufacturerproducts RENAME COLUMN images_arr      TO "Images";
ALTER TABLE public.manufacturerproducts RENAME COLUMN metal_color_arr TO "Metal Color";
ALTER TABLE public.manufacturerproducts RENAME COLUMN category_arr    TO "Category";

-- Renaming a column keeps its indexes; rename them so names stay truthful.
ALTER INDEX IF EXISTS idx_products_category_arr             RENAME TO idx_products_category;
ALTER INDEX IF EXISTS idx_designerproducts_category_arr     RENAME TO idx_designerproducts_category;
ALTER INDEX IF EXISTS idx_manufacturerproducts_category_arr RENAME TO idx_manufacturerproducts_category;

-- The app filters metal colors with array overlap (.overlaps) — give it a GIN
-- index on all three tables (Phase 1 only indexed category_arr).
CREATE INDEX IF NOT EXISTS idx_products_metal_color             ON public.products             USING gin ("Metal Color");
CREATE INDEX IF NOT EXISTS idx_designerproducts_metal_color     ON public.designerproducts     USING gin ("Metal Color");
CREATE INDEX IF NOT EXISTS idx_manufacturerproducts_metal_color ON public.manufacturerproducts USING gin ("Metal Color");


-- ============================================================================
-- 6. RECREATE FUNCTIONS AGAINST THE NEW SHAPE
-- ----------------------------------------------------------------------------
-- LANGUAGE sql is used wherever possible: sql bodies are validated at CREATE
-- time, so a wrong column name aborts THIS migration instead of failing later
-- at first call (plpgsql bodies are only parsed, not validated).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 6a. get_similar_products — single new overload ("More Like This").
--     Replaces the scalar Category/Category1/2/3 AND-chain with array overlap
--     (&&) on the caller's full category list; "Product Type" and
--     "Sub Category" become ranking preferences instead of hard filters, so
--     same-type items surface first without starving results.
--     Returns "Images"/"Category" as arrays — same keys a post-migration table
--     row has, which jewelry_item.fromJson already handles.
-- ----------------------------------------------------------------------------
CREATE FUNCTION public.get_similar_products(
  p_product_type text DEFAULT NULL,
  p_category text DEFAULT NULL,
  p_sub_category text DEFAULT NULL,
  p_categories text[] DEFAULT NULL,
  p_limit int DEFAULT 10,
  p_exclude_id text DEFAULT NULL,
  p_is_designer boolean DEFAULT NULL
)
RETURNS TABLE (
  id text,
  "Product Title" text,
  "Images" text[],
  "Description" text,
  "Product Type" text,
  "Category" text[],
  "Sub Category" text,
  "Metal Type" text,
  "Metal Purity" text,
  "Plain" text,
  "Studded" text[],
  "Price" text,
  is_designer_product boolean
)
LANGUAGE sql STABLE AS $$
  WITH combined AS (
    SELECT
      p.id::text AS id, p."Product Title", p."Images", p."Description",
      p."Product Type", p."Category", p."Sub Category", p."Metal Type",
      p."Metal Purity", p."Plain", p."Studded", p."Price",
      FALSE AS is_designer_product
    FROM public.products p
    WHERE (p_is_designer IS NULL OR p_is_designer = FALSE)
      AND (p_exclude_id IS NULL OR p.id::text <> p_exclude_id)
      AND CASE
            WHEN p_categories IS NOT NULL AND array_length(p_categories, 1) > 0
              THEN p."Category" && p_categories
            WHEN p_category IS NOT NULL AND p_category <> ''
              THEN p_category = ANY(p."Category")
            WHEN p_product_type IS NOT NULL AND p_product_type <> ''
              THEN p."Product Type" = p_product_type
            ELSE TRUE
          END

    UNION ALL

    SELECT
      dp.id::text, dp."Product Title", dp."Images", dp."Description",
      dp."Product Type", dp."Category", dp."Sub Category", dp."Metal Type",
      dp."Metal Purity", dp."Plain", dp."Studded", dp."Price",
      TRUE AS is_designer_product
    FROM public.designerproducts dp
    WHERE (p_is_designer IS NULL OR p_is_designer = TRUE)
      AND (p_exclude_id IS NULL OR dp.id::text <> p_exclude_id)
      AND CASE
            WHEN p_categories IS NOT NULL AND array_length(p_categories, 1) > 0
              THEN dp."Category" && p_categories
            WHEN p_category IS NOT NULL AND p_category <> ''
              THEN p_category = ANY(dp."Category")
            WHEN p_product_type IS NOT NULL AND p_product_type <> ''
              THEN dp."Product Type" = p_product_type
            ELSE TRUE
          END
  )
  SELECT * FROM combined
  ORDER BY
    CASE WHEN p_product_type IS NOT NULL AND "Product Type" = p_product_type THEN 0 ELSE 1 END,
    CASE WHEN p_sub_category IS NOT NULL AND "Sub Category" = p_sub_category THEN 0 ELSE 1 END,
    random()
  LIMIT p_limit;
$$;

-- ----------------------------------------------------------------------------
-- 6b. search_inventory_with_metrics — thumb/media from "Images"[1]; category
--     rendered as a comma-joined string (display-only in the admin UI);
--     products.created_at now exists (added in Phase 1), so return it.
-- ----------------------------------------------------------------------------
CREATE FUNCTION public.search_inventory_with_metrics(
  p_table_filter text DEFAULT 'all',
  p_search_term text DEFAULT '',
  p_min_likes int DEFAULT 0,
  p_min_views int DEFAULT 0,
  p_min_shares int DEFAULT 0,
  p_min_credits int DEFAULT 0,
  p_product_type text DEFAULT NULL,
  p_start_date timestamptz DEFAULT NULL,
  p_end_date timestamptz DEFAULT NULL,
  p_limit int DEFAULT 100
) RETURNS TABLE (
  id text,
  title text,
  category text,
  status text,
  source text,
  thumb_url text,
  media_url text,
  owner_id uuid,
  created_at timestamptz,
  product_type text,
  likes_count bigint,
  views_count bigint,
  shares_count bigint,
  credits_used bigint
)
LANGUAGE sql STABLE AS $$
  WITH all_items AS (
    SELECT p.id::text AS id, p."Product Title" AS title,
           NULLIF(array_to_string(p."Category", ', '), '') AS category,
           'uploaded' AS status, 'products' AS source,
           (p."Images")[1] AS thumb_url, (p."Images")[1] AS media_url,
           p.user_id AS owner_id, p.created_at, p."Product Type" AS product_type
    FROM public.products p
    WHERE (p_table_filter = 'all' OR p_table_filter = 'products')

    UNION ALL

    SELECT d.id::text, d."Product Title",
           NULLIF(array_to_string(d."Category", ', '), ''),
           'uploaded', 'designerproducts',
           (d."Images")[1], (d."Images")[1],
           d.user_id, d.created_at, d."Product Type"
    FROM public.designerproducts d
    WHERE (p_table_filter = 'all' OR p_table_filter = 'designerproducts')

    UNION ALL

    SELECT m.id::text, m."Product Title",
           NULLIF(array_to_string(m."Category", ', '), ''),
           'uploaded', 'manufacturerproducts',
           (m."Images")[1], (m."Images")[1],
           m.user_id, m.created_at, m."Product Type"
    FROM public.manufacturerproducts m
    WHERE (p_table_filter = 'all' OR p_table_filter = 'manufacturerproducts')
  ),
  filtered_items AS (
    SELECT * FROM all_items
    WHERE (p_search_term = '' OR title ILIKE '%' || p_search_term || '%')
      AND (p_product_type IS NULL OR p_product_type = '' OR product_type ILIKE '%' || p_product_type || '%')
  ),
  metrics AS (
    SELECT fi.*,
      (SELECT COUNT(*) FROM public.likes l  WHERE l.item_id = fi.id AND l.item_table = fi.source AND (p_start_date IS NULL OR l.created_at >= p_start_date) AND (p_end_date IS NULL OR l.created_at <= p_end_date)) AS likes_count,
      (SELECT COUNT(*) FROM public.views v  WHERE v.item_id = fi.id AND v.item_table = fi.source AND (p_start_date IS NULL OR v.created_at >= p_start_date) AND (p_end_date IS NULL OR v.created_at <= p_end_date)) AS views_count,
      (SELECT COUNT(*) FROM public.shares s WHERE s.item_id = fi.id AND s.item_table = fi.source AND (p_start_date IS NULL OR s.created_at >= p_start_date) AND (p_end_date IS NULL OR s.created_at <= p_end_date)) AS shares_count,
      (SELECT COUNT(*) FROM public.user_unlocked_items u WHERE u.item_id = fi.id AND (p_start_date IS NULL OR u.unlocked_at >= p_start_date) AND (p_end_date IS NULL OR u.unlocked_at <= p_end_date)) AS credits_used
    FROM filtered_items fi
  )
  SELECT * FROM metrics
  WHERE likes_count >= p_min_likes
    AND views_count >= p_min_views
    AND shares_count >= p_min_shares
    AND credits_used >= p_min_credits
  ORDER BY created_at DESC NULLS LAST
  LIMIT p_limit;
$$;

-- ----------------------------------------------------------------------------
-- 6c. get_distinct_category_values — unnest the unified "Category" array.
--     Now also includes manufacturerproducts (the old version predated it).
-- ----------------------------------------------------------------------------
CREATE FUNCTION public.get_distinct_category_values()
RETURNS TABLE (value text)
LANGUAGE sql STABLE AS $$
  SELECT DISTINCT cat AS value
  FROM (
    SELECT unnest("Category") FROM public.products
    UNION ALL
    SELECT unnest("Category") FROM public.designerproducts
    UNION ALL
    SELECT unnest("Category") FROM public.manufacturerproducts
  ) AS t(cat)
  WHERE cat IS NOT NULL AND btrim(cat) <> ''
  ORDER BY value;
$$;

-- ----------------------------------------------------------------------------
-- 6d. get_category_performance_analytics — REWRITTEN TO ACTUALLY WORK.
--     The old body was invalid (ungrouped column refs + unnest() on a scalar)
--     and threw on every call — the admin dashboard has been silently falling
--     back to mock data. Each product now counts toward EVERY category in its
--     array; NULL/empty category groups as 'Unknown'.
-- ----------------------------------------------------------------------------
CREATE FUNCTION public.get_category_performance_analytics()
RETURNS TABLE (
  category text,
  product_count bigint,
  avg_views numeric,
  avg_likes numeric,
  top_tags text[],
  top_colors text[]
)
LANGUAGE sql STABLE AS $$
  WITH exploded AS (
    SELECT COALESCE(cat, 'Unknown') AS category, p.id,
           p."Product Tags" AS tags, p."Metal Color" AS colors
    FROM public.products p
    LEFT JOIN LATERAL unnest(
      CASE WHEN p."Category" IS NULL OR cardinality(p."Category") = 0
           THEN ARRAY[NULL]::text[] ELSE p."Category" END
    ) AS cat ON TRUE
  ),
  with_metrics AS (
    SELECT e.category, e.id, e.tags, e.colors,
      (SELECT COUNT(*) FROM public.views v WHERE v.item_id = e.id::text) AS views_ct,
      (SELECT COUNT(*) FROM public.likes l WHERE l.item_id = e.id::text) AS likes_ct
    FROM exploded e
  )
  SELECT
    w.category,
    COUNT(*)::bigint AS product_count,
    AVG(w.views_ct)::numeric AS avg_views,
    AVG(w.likes_ct)::numeric AS avg_likes,
    ARRAY(SELECT DISTINCT t FROM with_metrics w2, unnest(COALESCE(w2.tags,  '{}'::text[])) AS t
          WHERE w2.category = w.category LIMIT 3) AS top_tags,
    ARRAY(SELECT DISTINCT c FROM with_metrics w3, unnest(COALESCE(w3.colors, '{}'::text[])) AS c
          WHERE w3.category = w.category LIMIT 3) AS top_colors
  FROM with_metrics w
  GROUP BY w.category
  ORDER BY product_count DESC;
$$;

-- ----------------------------------------------------------------------------
-- 6e. get_top_content_analytics — media from "Images"[1]; real created_at.
-- ----------------------------------------------------------------------------
CREATE FUNCTION public.get_top_content_analytics(limit_count integer)
RETURNS TABLE (
  id text,
  title text,
  category text,
  views bigint,
  likes bigint,
  saves bigint,
  media_url text,
  created_at timestamptz
)
LANGUAGE sql STABLE AS $$
  WITH content_stats AS (
    SELECT v.item_id, COUNT(v.id) AS view_count
    FROM public.views v
    GROUP BY v.item_id
  )
  SELECT
    p.id::text,
    p."Product Title" AS title,
    NULLIF(array_to_string(p."Category", ', '), '') AS category,
    COALESCE(s.view_count, 0) AS views,
    (SELECT COUNT(*) FROM public.likes l WHERE l.item_id = p.id::text) AS likes,
    (SELECT COUNT(*) FROM public.user_likes ul WHERE ul.pin_id::text = p.id::text) AS saves,
    (p."Images")[1] AS media_url,
    COALESCE(p.created_at, now()) AS created_at
  FROM public.products p
  LEFT JOIN content_stats s ON s.item_id = p.id::text
  ORDER BY views DESC
  LIMIT limit_count;
$$;

-- ----------------------------------------------------------------------------
-- 6f. match_products — same signature and return shape (output column stays
--     named "Image" so the AI-lens caller is untouched), sourced from "Images".
-- ----------------------------------------------------------------------------
CREATE FUNCTION public.match_products(
  query_embedding extensions.vector(512),
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
LANGUAGE sql STABLE AS $$
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
  ORDER BY similarity DESC
  LIMIT match_count;
$$;

-- ----------------------------------------------------------------------------
-- 6g. search_products_fts — Category1/2/3 are gone: return shape loses those
--     three columns and "Category" becomes text[]; category matching searches
--     the whole array (comma-joined for ILIKE).
-- ----------------------------------------------------------------------------
CREATE FUNCTION public.search_products_fts(
  search_query text,
  limit_count int DEFAULT 50
)
RETURNS TABLE (
  id text,
  "Product Title" text,
  "Image" text,
  "Description" text,
  "Product Type" text,
  "Category" text[],
  "Sub Category" text,
  "Metal Type" text,
  "Metal Purity" text,
  "Plain" text,
  "Studded" text[],
  "Price" text,
  is_designer_product boolean
)
LANGUAGE sql STABLE AS $$
  WITH combined_results AS (
    SELECT
      p.id::text AS id, p."Product Title", (p."Images")[1] AS "Image",
      p."Description", p."Product Type", p."Category", p."Sub Category",
      p."Metal Type", p."Metal Purity", p."Plain", p."Studded", p."Price",
      FALSE AS is_designer_product,
      CASE
        WHEN p."Product Title" ILIKE '%' || search_query || '%' THEN 1
        WHEN p."Product Type" ILIKE '%' || search_query || '%' THEN 2
        WHEN array_to_string(p."Category", ' ') ILIKE '%' || search_query || '%' THEN 3
        ELSE 4
      END AS relevance
    FROM public.products p
    WHERE p."Product Title" ILIKE '%' || search_query || '%'
       OR p."Description" ILIKE '%' || search_query || '%'
       OR p."Product Type" ILIKE '%' || search_query || '%'
       OR array_to_string(p."Category", ' ') ILIKE '%' || search_query || '%'

    UNION ALL

    SELECT
      dp.id::text, dp."Product Title", (dp."Images")[1],
      dp."Description", dp."Product Type", dp."Category", dp."Sub Category",
      dp."Metal Type", dp."Metal Purity", dp."Plain", dp."Studded", dp."Price",
      TRUE,
      CASE
        WHEN dp."Product Title" ILIKE '%' || search_query || '%' THEN 1
        WHEN dp."Product Type" ILIKE '%' || search_query || '%' THEN 2
        WHEN array_to_string(dp."Category", ' ') ILIKE '%' || search_query || '%' THEN 3
        ELSE 4
      END
    FROM public.designerproducts dp
    WHERE dp."Product Title" ILIKE '%' || search_query || '%'
       OR dp."Description" ILIKE '%' || search_query || '%'
       OR dp."Product Type" ILIKE '%' || search_query || '%'
       OR array_to_string(dp."Category", ' ') ILIKE '%' || search_query || '%'
  )
  SELECT cr.id, cr."Product Title", cr."Image", cr."Description",
         cr."Product Type", cr."Category", cr."Sub Category", cr."Metal Type",
         cr."Metal Purity", cr."Plain", cr."Studded", cr."Price",
         cr.is_designer_product
  FROM combined_results cr
  ORDER BY cr.relevance, cr."Product Title"
  LIMIT limit_count;
$$;

-- ----------------------------------------------------------------------------
-- 6h. search_all_products — images_arr renamed; body otherwise unchanged from
--     the Phase 2 fix.
-- ----------------------------------------------------------------------------
CREATE FUNCTION public.search_all_products(
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
LANGUAGE sql STABLE AS $$
  SELECT
    p.id::text,
    p."Product Title" AS product_title,
    (p."Images")[1] AS image,
    NULLIF(p."Price", '')::numeric AS price,
    FALSE AS is_designer_product,
    1 - (p.embedding <=> query_embedding) AS similarity
  FROM public.products p
  WHERE p.embedding IS NOT NULL
    AND 1 - (p.embedding <=> query_embedding) > match_threshold

  UNION ALL

  SELECT
    dp.id::text,
    dp."Product Title",
    (dp."Images")[1],
    NULLIF(dp."Price", '')::numeric,
    TRUE,
    1 - (dp.embedding <=> query_embedding)
  FROM public.designerproducts dp
  WHERE dp.embedding IS NOT NULL
    AND 1 - (dp.embedding <=> query_embedding) > match_threshold

  ORDER BY similarity DESC
  LIMIT match_count;
$$;

-- ----------------------------------------------------------------------------
-- 6i. get_filtered_scraped_posts / get_scraped_posts_with_metrics — image from
--     "Images"[1]; the returned category is the FIRST array element so the
--     value shown in the admin filter dropdown round-trips through the
--     `category_filter = ANY("Category")` match.
-- ----------------------------------------------------------------------------
CREATE FUNCTION public.get_filtered_scraped_posts(
  category_filter text,
  material_filter text,
  search_text text
)
RETURNS TABLE (
  id integer,
  title text,
  image text,
  category text,
  metal_type text,
  view_count bigint,
  like_count bigint,
  share_count bigint
)
LANGUAGE sql STABLE AS $$
  SELECT
    p.id,
    p."Product Title" AS title,
    (p."Images")[1] AS image,
    (p."Category")[1] AS category,
    p."Metal Type" AS metal_type,
    (SELECT COUNT(*) FROM public.views v   WHERE v.item_id  = p.id::text AND v.item_table  = 'products') AS view_count,
    (SELECT COUNT(*) FROM public.likes l   WHERE l.item_id  = p.id::text AND l.item_table  = 'products') AS like_count,
    (SELECT COUNT(*) FROM public.shares sh WHERE sh.item_id = p.id::text AND sh.item_table = 'products') AS share_count
  FROM public.products p
  WHERE (category_filter IS NULL OR category_filter = ANY(p."Category"))
    AND (material_filter IS NULL OR p."Metal Type" = material_filter)
    AND (search_text IS NULL OR search_text = '' OR p."Product Title" ~* search_text)

  UNION ALL

  SELECT
    dp.id,
    dp."Product Title",
    (dp."Images")[1],
    (dp."Category")[1],
    dp."Metal Type",
    (SELECT COUNT(*) FROM public.views v   WHERE v.item_id  = dp.id::text AND v.item_table  = 'designerproducts'),
    (SELECT COUNT(*) FROM public.likes l   WHERE l.item_id  = dp.id::text AND l.item_table  = 'designerproducts'),
    (SELECT COUNT(*) FROM public.shares sh WHERE sh.item_id = dp.id::text AND sh.item_table = 'designerproducts')
  FROM public.designerproducts dp
  WHERE (category_filter IS NULL OR category_filter = ANY(dp."Category"))
    AND (material_filter IS NULL OR dp."Metal Type" = material_filter)
    AND (search_text IS NULL OR search_text = '' OR dp."Product Title" ~* search_text)

  ORDER BY like_count DESC, view_count DESC;
$$;

CREATE FUNCTION public.get_scraped_posts_with_metrics()
RETURNS TABLE (
  id integer,
  title text,
  image text,
  category text,
  metal_type text,
  view_count bigint,
  like_count bigint,
  share_count bigint
)
LANGUAGE sql STABLE AS $$
  SELECT * FROM public.get_filtered_scraped_posts(NULL, NULL, NULL);
$$;

-- ----------------------------------------------------------------------------
-- 6j. get_initial_search_ideas — category ideas come from unnesting the array.
-- ----------------------------------------------------------------------------
CREATE FUNCTION public.get_initial_search_ideas(limit_count int)
RETURNS SETOF text
LANGUAGE sql STABLE AS $$
  SELECT idea FROM (
    SELECT DISTINCT unnest("Category") AS idea FROM public.products
    UNION
    SELECT DISTINCT "Product Type" FROM public.products
    WHERE "Product Type" IS NOT NULL AND "Product Type" <> ''
    UNION
    SELECT DISTINCT "Theme" FROM public.products
    WHERE "Theme" IS NOT NULL AND "Theme" <> ''
    UNION
    SELECT DISTINCT unnest("Product Tags") FROM public.products
    WHERE "Product Tags" IS NOT NULL
  ) ideas
  ORDER BY random()
  LIMIT limit_count;
$$;

-- ----------------------------------------------------------------------------
-- 6k. get_category_distribution — count per category array element.
-- ----------------------------------------------------------------------------
CREATE FUNCTION public.get_category_distribution()
RETURNS TABLE (category text, count bigint)
LANGUAGE sql STABLE AS $$
  SELECT cat AS category, COUNT(*) AS count
  FROM public.products p
  CROSS JOIN LATERAL unnest(p."Category") AS cat
  WHERE cat IS NOT NULL AND btrim(cat) <> ''
  GROUP BY cat
  ORDER BY COUNT(*) DESC;
$$;

-- ----------------------------------------------------------------------------
-- 6l. Phase 2 analytics RPCs — category_arr renamed to "Category".
-- ----------------------------------------------------------------------------
CREATE FUNCTION public.product_type_counts_by_category(
  p_table_filter text DEFAULT 'all'
)
RETURNS TABLE (category text, product_type text, item_count bigint)
LANGUAGE sql STABLE AS $$
  WITH all_p AS (
    SELECT "Category" AS category_list, "Product Type" AS product_type, 'products' AS src
      FROM public.products
    UNION ALL
    SELECT "Category", "Product Type", 'designerproducts'
      FROM public.designerproducts
    UNION ALL
    SELECT "Category", "Product Type", 'manufacturerproducts'
      FROM public.manufacturerproducts
  )
  SELECT
    cat AS category,
    COALESCE(product_type, '(unspecified)') AS product_type,
    COUNT(*) AS item_count
  FROM all_p
  CROSS JOIN LATERAL unnest(all_p.category_list) AS cat
  WHERE (p_table_filter = 'all' OR src = p_table_filter)
  GROUP BY cat, product_type
  ORDER BY cat, item_count DESC;
$$;

CREATE FUNCTION public.plain_studded_counts_by_category(
  p_table_filter text DEFAULT 'all'
)
RETURNS TABLE (category text, plain_count bigint, studded_count bigint, total_count bigint)
LANGUAGE sql STABLE AS $$
  WITH all_p AS (
    SELECT "Category" AS category_list, "Plain" AS plain, "Studded" AS studded, 'products' AS src
      FROM public.products
    UNION ALL
    SELECT "Category", "Plain", "Studded", 'designerproducts'
      FROM public.designerproducts
    UNION ALL
    SELECT "Category", "Plain", "Studded", 'manufacturerproducts'
      FROM public.manufacturerproducts
  )
  SELECT
    cat AS category,
    COUNT(*) FILTER (WHERE plain IS NOT NULL AND btrim(plain) <> '')             AS plain_count,
    COUNT(*) FILTER (WHERE studded IS NOT NULL AND array_length(studded, 1) > 0) AS studded_count,
    COUNT(*)                                                                     AS total_count
  FROM all_p
  CROSS JOIN LATERAL unnest(all_p.category_list) AS cat
  WHERE (p_table_filter = 'all' OR src = p_table_filter)
  GROUP BY cat
  ORDER BY total_count DESC, category;
$$;


-- ============================================================================
-- 7. GRANTS — DROP FUNCTION discards ACLs; restore the standard Supabase set.
-- ============================================================================
GRANT EXECUTE ON FUNCTION public.get_similar_products(text, text, text, text[], int, text, boolean) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.search_inventory_with_metrics(text, text, int, int, int, int, text, timestamptz, timestamptz, int) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_distinct_category_values() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_category_performance_analytics() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_top_content_analytics(integer) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.match_products(extensions.vector, double precision, integer) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.search_products_fts(text, int) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.search_all_products(extensions.vector, double precision, integer) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_filtered_scraped_posts(text, text, text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_scraped_posts_with_metrics() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_initial_search_ideas(int) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_category_distribution() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.product_type_counts_by_category(text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.plain_studded_counts_by_category(text) TO anon, authenticated, service_role;


-- ============================================================================
-- 8. FK STANDARDIZATION — products.user_id -> public.users(id) CASCADE
-- ----------------------------------------------------------------------------
-- Aborts (rolling back everything above) if any products row references a
-- user_id that has no public.users row — resolve orphans first in that case.
-- ============================================================================
DO $$
DECLARE
  orphan_count bigint;
  fk record;
BEGIN
  SELECT COUNT(*) INTO orphan_count
  FROM public.products p
  LEFT JOIN public.users u ON p.user_id = u.id
  WHERE p.user_id IS NOT NULL AND u.id IS NULL;

  IF orphan_count > 0 THEN
    RAISE EXCEPTION 'Phase 3 FK gate: % products rows have user_id with no public.users row — resolve orphans before adding the FK', orphan_count;
  END IF;

  -- Drop whatever FK(s) currently exist on products.user_id (name has drifted).
  FOR fk IN
    SELECT c.conname
    FROM pg_constraint c
    JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = ANY (c.conkey)
    WHERE c.conrelid = 'public.products'::regclass
      AND c.contype = 'f'
      AND a.attname = 'user_id'
  LOOP
    EXECUTE format('ALTER TABLE public.products DROP CONSTRAINT %I', fk.conname);
  END LOOP;

  ALTER TABLE public.products
    ADD CONSTRAINT products_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;
END $$;
