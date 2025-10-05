ALTER TABLE public.assets
ADD COLUMN source TEXT DEFAULT 'uploaded';

COMMENT ON COLUMN public.assets.source IS 'Indicates the origin of the asset, e.g., ''uploaded'' or ''scraped''';