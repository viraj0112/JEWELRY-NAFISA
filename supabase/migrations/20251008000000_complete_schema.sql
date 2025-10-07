-- General setup
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_cron";

--================================================-
-- Step 1: Define Custom Types
--================================================-
-- Defines user roles for the application.
CREATE TYPE public.user_role AS ENUM ('member', 'designer', 'admin');
-- Defines visibility states for assets.
CREATE TYPE public.asset_visibility AS ENUM ('public', 'hidden');
-- Defines approval statuses for assets.
CREATE TYPE public.asset_status AS ENUM ('pending', 'approved', 'rejected');

--================================================-
-- Step 2: Create Core Tables
--================================================-
-- User Profiles Table
CREATE TABLE public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE,
    full_name TEXT,
    email TEXT,
    birthdate DATE,
    avatar_url TEXT,
    gender TEXT,
    role user_role DEFAULT 'member',
    business_name TEXT,
    business_type TEXT,
    phone TEXT,
    approval_status TEXT DEFAULT 'pending' NOT NULL,
    is_member BOOLEAN DEFAULT FALSE,
    membership_plan TEXT,
    credits_remaining INT NOT NULL DEFAULT 0,
    last_credit_refresh TIMESTAMPTZ,
    referral_code TEXT UNIQUE,
    referred_by UUID REFERENCES public.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Products Table (for scraped items)
CREATE TABLE public.products (
    id bigserial PRIMARY KEY,
    title TEXT,
    image TEXT,
    description TEXT,
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
    scraped_url TEXT
);

-- User-Generated Content ("Pins") Table
CREATE TABLE public.pins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES public.users(id),
    title TEXT NOT NULL,
    description TEXT,
    image_url TEXT NOT NULL,
    like_count INT DEFAULT 0,
    share_slug TEXT UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User-Created Boards Table
CREATE TABLE public.boards (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.users(id),
    name TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- B2B Creator Assets Table
CREATE TABLE public.assets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    media_url TEXT NOT NULL,
    thumb_url TEXT,
    category TEXT,
    tags TEXT[],
    sku TEXT,
    attributes JSONB,
    visibility asset_visibility DEFAULT 'public'::asset_visibility,
    status asset_status DEFAULT 'pending'::asset_status,
    source TEXT DEFAULT 'uploaded',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Notifications Table
CREATE TABLE public.notifications(
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Settings Table
CREATE TABLE public.settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    description TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

--================================================-
-- Step 3: Create Join & Tracking Tables
--================================================-
-- Many-to-Many join table for Boards and Pins
CREATE TABLE public.boards_pins (
    board_id INT NOT NULL REFERENCES public.boards(id) ON DELETE CASCADE,
    pin_id UUID NOT NULL REFERENCES public.pins(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (board_id, pin_id)
);

-- Tracks which users liked which pins
CREATE TABLE public.user_likes (
    user_id UUID NOT NULL REFERENCES public.users(id),
    pin_id UUID NOT NULL REFERENCES public.pins(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (user_id, pin_id)
);

-- Referrals tracking table
CREATE TABLE public.referrals (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    referrer_id UUID NOT NULL REFERENCES public.users(id),
    referred_id UUID NOT NULL REFERENCES public.users(id),
    credits_awarded INT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Daily Analytics Table
CREATE TABLE public.analytics_daily (
    date DATE NOT NULL,
    asset_id UUID NOT NULL,
    views INT DEFAULT 0,
    likes INT DEFAULT 0,
    saves INT DEFAULT 0,
    quotes_requested INT DEFAULT 0,
    shares INT DEFAULT 0,
    region_counts JSONB,
    PRIMARY KEY (date, asset_id)
);

--================================================-
-- Step 4: Create Functions & Triggers
--================================================-
-- Function to create a user profile upon signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (
    id, email, username, birthdate, role,
    business_name, business_type, phone
  )
  VALUES (
    NEW.id, NEW.email,
    COALESCE(
      NEW.raw_user_meta_data ->> 'username',
      NEW.raw_user_meta_data ->> 'business_name'
    ),
    (NEW.raw_user_meta_data ->> 'birthdate')::date,
    (NEW.raw_user_meta_data ->> 'role')::user_role,
    NEW.raw_user_meta_data ->> 'business_name',
    NEW.raw_user_meta_data ->> 'business_type',
    NEW.raw_user_meta_data ->> 'phone'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Trigger to execute the function on new user creation
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Other helper functions
CREATE OR REPLACE FUNCTION public.increment_like_count(pin_id_to_update UUID, delta INTEGER)
RETURNS VOID AS $$
BEGIN
  UPDATE public.pins
  SET like_count = like_count + delta
  WHERE id = pin_id_to_update;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.decrement_credit()
RETURNS VOID AS $$
BEGIN
  UPDATE public.users
  SET credits_remaining = credits_remaining - 1
  WHERE id = auth.uid() AND credits_remaining > 0;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.increment_user_credits(user_id_to_update UUID, credits_to_add INT)
RETURNS VOID AS $$
BEGIN
  UPDATE public.users
  SET credits_remaining = credits_remaining + credits_to_add
  WHERE id = user_id_to_update;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

--================================================-
-- Step 5: Setup Row Level Security (RLS)
--================================================-
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.boards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.boards_pins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_daily ENABLE ROW LEVEL SECURITY;

-- POLICIES
CREATE POLICY "Public can view all products" ON public.products FOR SELECT USING (true);
CREATE POLICY "Users can view their own profile" ON public.users FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can create their own profile" ON public.users FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "Users can update their own profile" ON public.users FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Anyone can view pins" ON public.pins FOR SELECT USING (true);
CREATE POLICY "Users can create pins" ON public.pins FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Users can manage their likes" ON public.user_likes FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Designers can manage their own assets" ON public.assets FOR ALL USING (auth.uid() = owner_id) WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Admins have full access" ON public.assets FOR ALL USING (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin'::user_role));
CREATE POLICY "Users can view their own notifications" ON public.notifications FOR SELECT USING (auth.uid() = user_id);

--================================================-
-- Step 6: Insert Default Data & Schedule Jobs
--================================================-
-- Insert default settings
INSERT INTO public.settings (key, value, description) VALUES
  ('daily_reset_time_utc', '00:00', 'The time (UTC) when member credits are reset daily.'),
  ('signup_bonus_credits', '1', 'Credits awarded to a new user on signup.'),
  ('referral_bonus_member', '3', 'Credits awarded to a member for a successful referral.'),
  ('referral_bonus_non_member', '2', 'Credits awarded to a non-member for a successful referral.')
ON CONFLICT (key) DO NOTHING;

-- Schedule daily credit reset
SELECT cron.schedule(
    'reset-daily-credits',
    '0 0 * * *',
    'SELECT public.reset_daily_credits_for_members()'
);