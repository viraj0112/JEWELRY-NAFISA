CREATE TABLE IF NOT EXISTS public.analytics_daily (
  date DATE NOT NULL,
  asset_id UUID NOT NULL REFERENCES public.assets(id) ON DELETE CASCADE,
  views INT DEFAULT 0,
  likes INT DEFAULT 0,
  saves INT DEFAULT 0,
  quotes_requested INT DEFAULT 0,
  region_counts JSONB,
  PRIMARY KEY (date, asset_id)
);

ALTER TABLE public.analytics_daily ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Designers can view their own analytics"
  ON public.analytics_daily FOR SELECT
  USING (auth.uid() = (SELECT owner_id FROM public.assets WHERE id = asset_id));

CREATE POLICY "Admins can view all analytics"
  ON public.analytics_daily FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin'::user_role));