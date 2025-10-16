-- Create the "likes" table to track likes
CREATE TABLE public.likes (
    id BIGSERIAL PRIMARY KEY,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    user_id UUID NOT NULL REFERENCES public.users(id), -- The user who liked the item
    pin_id UUID REFERENCES public.pins(id) ON DELETE CASCADE,
    product_id BIGINT REFERENCES public.designerproducts(id) ON DELETE CASCADE,
    -- A user can only like a specific item once
    UNIQUE(user_id, pin_id),
    UNIQUE(user_id, product_id),
    -- Ensure each like is for either a pin or a product, not both
    CONSTRAINT chk_like_link CHECK ((pin_id IS NOT NULL AND product_id IS NULL) OR (pin_id IS NULL AND product_id IS NOT NULL))
);