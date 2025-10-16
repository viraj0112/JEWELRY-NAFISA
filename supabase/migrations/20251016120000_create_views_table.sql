CREATE TABLE public.views (
    id BIGSERIAL PRIMARY KEY,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    user_id UUID REFERENCES public.users(id), -- The user who viewed the item (optional)
    pin_id UUID REFERENCES public.pins(id) ON DELETE CASCADE,
    product_id BIGINT REFERENCES public.designerproducts(id) ON DELETE CASCADE,
    country TEXT, -- For geo-analytics
    -- Ensure that each view is linked to either a pin or a product, but not both
    CONSTRAINT chk_view_link CHECK ((pin_id IS NOT NULL AND product_id IS NULL) OR (pin_id IS NULL AND product_id IS NOT NULL))
);