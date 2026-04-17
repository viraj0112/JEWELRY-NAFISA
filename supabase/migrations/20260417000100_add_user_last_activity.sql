-- Add last_activity_at column to users table
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS last_activity_at TIMESTAMPTZ;

-- Backfill last_activity_at with max created_at from views
UPDATE public.users u
SET last_activity_at = (
    SELECT MAX(created_at)
    FROM public.views v
    WHERE v.user_id = u.id
);

-- Trigger function to update last_activity_at on new view
CREATE OR REPLACE FUNCTION update_user_last_activity()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.users
    SET last_activity_at = NEW.created_at
    WHERE id = NEW.user_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to call the function on insert to views
DROP TRIGGER IF EXISTS update_last_activity_trigger ON public.views;
CREATE TRIGGER update_last_activity_trigger
AFTER INSERT ON public.views
FOR EACH ROW
EXECUTE FUNCTION update_user_last_activity();
