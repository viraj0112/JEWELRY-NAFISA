-- Create a new type called 'user_role' to ensure data consistency.
CREATE TYPE public.user_role AS ENUM ('member', 'designer', 'admin');

-- Add the new columns to your 'users' table.
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS role user_role DEFAULT 'member',
  ADD COLUMN IF NOT EXISTS business_name TEXT,
  ADD COLUMN IF NOT EXISTS business_type TEXT, -- This will store '3D Designer' or 'Sketch Artist'
  ADD COLUMN IF NOT EXISTS phone TEXT,
  ADD COLUMN IF NOT EXISTS approval_status TEXT DEFAULT 'pending' NOT NULL; -- Statuses: 'pending', 'approved', 'rejected'

DROP POLICY IF EXISTS "Users can view their own profile" ON public.users;
CREATE POLICY "Users can view their own profile"
  ON public.users FOR SELECT
  USING (auth.uid() = id);