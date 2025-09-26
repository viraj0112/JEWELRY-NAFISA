
CREATE TABLE IF NOT EXISTS public.products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  title TEXT NOT NULL,
  description TEXT,
  price NUMERIC,
  image_url TEXT,
  tags TEXT[],   
  category TEXT,
  sub_category TEXT,
  metal TEXT,
  purity TEXT,
  stone_type TEXT,
  dimensions TEXT,
  attributes JSONB 
);


ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public can view all products" ON public.products; 
CREATE POLICY "Public can view all products"
  ON public.products FOR SELECT
  USING (true);