CREATE TABLE public.designerproducts (
    id bigserial PRIMARY KEY,
    designer_id UUID REFERENCES public.users(id),
    title TEXT,
    description TEXT,
    image TEXT, -- This will store the public URL of the image
    price TEXT,
    tags TEXT[],
    gold_weight TEXT,
    gold_carat TEXT,
    gold_finish TEXT,
    stone_weight TEXT,
    stone_type TEXT,
    stone_used TEXT,
    stone_setting TEXT,
    stone_purity TEXT,
    stone_count TEXT,
    category TEXT,
    sub_category TEXT,
    size TEXT,
    occasions TEXT,
    style TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);