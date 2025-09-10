-- In file: supabase/migrations/20250909000000_fix_membership_columns.sql

-- Renames the old column to match what the function code expects
ALTER TABLE public.users
RENAME COLUMN membership_status TO membership_plan;

ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS is_member BOOLEAN DEFAULT FALSE;