CREATE TABLE public.quote_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT NOW(),

    -- User Details
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    user_name TEXT,
    user_email TEXT,
    user_phone TEXT, 

    -- Product Details
    product_id BIGINT NOT NULL, 
    product_table TEXT NOT NULL CHECK (product_table IN ('products', 'designerproducts')), 
    product_title TEXT,

    -- All other product fields
    metal_purity TEXT, 
    gold_weight TEXT, 
    metal_color TEXT, 
    metal_finish TEXT, 
    metal_type TEXT, 
    stone_type TEXT[], -- <-- ADDED (as text array)
    stone_color TEXT[], -- <-- ADDED (as text array)
    stone_count TEXT[], -- <-- ADDED (as text array)
    stone_purity TEXT[], -- <-- ADDED (as text array)
    stone_cut TEXT[], -- <-- ADDED (as text array)
    stone_used TEXT[], -- <-- ADDED (as text array)
    stone_weight TEXT[], -- <-- ADDED (as text array)
    stone_setting TEXT[], -- <-- ADDED (as text array)
    
    -- User's Optional Notes
    additional_notes TEXT 
);

-- Comments
COMMENT ON TABLE public.quote_requests IS 'Stores quote requests submitted by users via the popup.';
COMMENT ON COLUMN public.quote_requests.user_phone IS 'User''s phone number, auto-fetched from their profile.';
COMMENT ON COLUMN public.quote_requests.additional_notes IS 'Optional details (max 250 words) provided by the user in the quote popup.';

-- Enable Row Level Security
ALTER TABLE public.quote_requests ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Users can insert their own quote requests"
ON public.quote_requests FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view their own quote requests"
ON public.quote_requests FOR SELECT
TO authenticated
USING (auth.uid() = user_id);