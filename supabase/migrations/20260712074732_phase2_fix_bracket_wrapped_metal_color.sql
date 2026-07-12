-- ============================================================================
-- FIX: dirty data where "Metal Color" itself holds a stringified array, e.g.
-- the literal text  {Yellow Gold, Rose Gold}  (curly braces + comma, as a
-- single string) instead of a real value or a real array.
-- ============================================================================
-- The Phase 1 backfill did `ARRAY["Metal Color"]`, which correctly wraps a
-- NORMAL value ("Rose Gold" -> {"Rose Gold"}) but WRONGLY wraps a
-- bracket-string as a single one-element array containing the whole comma-
-- joined string ("{Yellow Gold, Rose Gold}" -> {"Yellow Gold, Rose Gold"}),
-- instead of splitting it into two real elements. This surfaced in the UI as
-- a bogus combined swatch option "Yellow Gold, Rose Gold" alongside the two
-- individual colors.
--
-- Fix: for any row whose "Metal Color" matches the bracket-string shape,
-- strip the braces and split on comma to get the real color list, then
-- re-run through the existing array_dedup_ordered() helper (trims + dedupes
-- + strips blanks) - same helper Phase 1 used everywhere else.
-- ============================================================================

UPDATE public.products
SET metal_color_arr = public.array_dedup_ordered(
  ARRAY(
    SELECT btrim(elem)
    FROM unnest(string_to_array(trim(both '{}' from "Metal Color"), ',')) AS elem
  )
)
WHERE "Metal Color" LIKE '{%}';

UPDATE public.designerproducts
SET metal_color_arr = public.array_dedup_ordered(
  ARRAY(
    SELECT btrim(elem)
    FROM unnest(string_to_array(trim(both '{}' from "Metal Color"), ',')) AS elem
  )
)
WHERE "Metal Color" LIKE '{%}';

UPDATE public.manufacturerproducts
SET metal_color_arr = public.array_dedup_ordered(
  ARRAY(
    SELECT btrim(elem)
    FROM unnest(string_to_array(trim(both '{}' from "Metal Color"), ',')) AS elem
  )
)
WHERE "Metal Color" LIKE '{%}';
