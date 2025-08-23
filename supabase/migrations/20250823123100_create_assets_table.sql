-- Create new types for managing asset status and visibility.
CREATE TYPE public.asset_visibility AS ENUM ('public', 'hidden');
CREATE TYPE public.asset_status AS ENUM ('pending', 'approved', 'rejected');

-- Create the 'assets' table.
CREATE TABLE IF NOT EXISTS public.assets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  media_url TEXT NOT NULL,
  thumb_url TEXT,
  category TEXT,
  tags TEXT[],
  sku TEXT,
  attributes JSONB, -- Stores details like metal, color, stones, etc.
  visibility asset_visibility DEFAULT 'public'::asset_visibility,
  status asset_status DEFAULT 'pending'::asset_status,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security on the new table.
ALTER TABLE public.assets ENABLE ROW LEVEL SECURITY;

-- Security Policy: Anyone can see assets that are public and approved by the admin.
CREATE POLICY "Public can view approved assets"
  ON public.assets FOR SELECT
  USING (status = 'approved'::asset_status AND visibility = 'public'::asset_visibility);

-- Security Policy: Designers can create, view, update, and delete their own assets.
CREATE POLICY "Designers can manage their own assets"
  ON public.assets FOR ALL
  USING (auth.uid() = owner_id)
  WITH CHECK (auth.uid() = owner_id);

-- Security Policy: The Admin can do anything with any asset.
CREATE POLICY "Admins have full access"
  ON public.assets FOR ALL
  USING (EXISTS (
    SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin'::user_role
  ));