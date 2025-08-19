-- Enable Row Level Security (RLS)
ALTER TABLE public.Users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.boards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.boards_pins ENABLE ROW LEVEL SECURITY;

-- Users policies
CREATE POLICY "Users can view their own profile" 
    ON public.Users FOR SELECT 
    USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile" 
    ON public.Users FOR UPDATE 
    USING (auth.uid() = id);

-- Pins policies
CREATE POLICY "Anyone can view pins" 
    ON public.pins FOR SELECT 
    USING (true);

CREATE POLICY "Users can create pins" 
    ON public.pins FOR INSERT 
    WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "Users can update own pins" 
    ON public.pins FOR UPDATE 
    USING (auth.uid() = owner_id);

-- Boards policies
CREATE POLICY "Users can view own boards" 
    ON public.boards FOR SELECT 
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create own boards" 
    ON public.boards FOR INSERT 
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own boards" 
    ON public.boards FOR UPDATE 
    USING (auth.uid() = user_id);

-- User likes policies
CREATE POLICY "Users can manage their likes" 
    ON public.user_likes FOR ALL 
    USING (auth.uid() = user_id);

-- Boards pins policies
CREATE POLICY "Users can manage their board pins" 
    ON public.boards_pins FOR ALL 
    USING (EXISTS (
        SELECT 1 FROM public.boards 
        WHERE id = board_id AND user_id = auth.uid()
    ));