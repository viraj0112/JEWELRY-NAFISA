-- ============================================================================
-- Persist which products were AI-filled
-- ----------------------------------------------------------------------------
-- The B2B catalog's "AI Filled" badge was driven by an in-memory list in the
-- app, so it vanished on refresh. The AI-fill backend now stamps each row it
-- writes, and the app reads the stamp:
--   ai_filled_at       last time AI wrote any field of this product
--   ai_filled_columns  every field AI has filled on it (accumulates)
-- Additive only; existing rows start unstamped.
-- ============================================================================

ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS ai_filled_at      timestamptz,
  ADD COLUMN IF NOT EXISTS ai_filled_columns text[];

ALTER TABLE public.designerproducts
  ADD COLUMN IF NOT EXISTS ai_filled_at      timestamptz,
  ADD COLUMN IF NOT EXISTS ai_filled_columns text[];

ALTER TABLE public.manufacturerproducts
  ADD COLUMN IF NOT EXISTS ai_filled_at      timestamptz,
  ADD COLUMN IF NOT EXISTS ai_filled_columns text[];
