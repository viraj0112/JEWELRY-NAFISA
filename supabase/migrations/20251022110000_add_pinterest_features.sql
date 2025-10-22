-- Add a 'type' to boards to distinguish between public and secret boards.
ALTER TABLE public.boards
ADD COLUMN is_secret BOOLEAN NOT NULL DEFAULT FALSE;

-- Create a table to manage collaborators on boards.
CREATE TABLE public.board_collaborators (
    board_id INTEGER NOT NULL REFERENCES public.boards(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (board_id, user_id)
);

-- Create a table for board sections.
CREATE TABLE public.board_sections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    board_id INTEGER NOT NULL REFERENCES public.boards(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add a foreign key to the pins table to link them to board sections.
ALTER TABLE public.pins
ADD COLUMN section_id UUID REFERENCES public.board_sections(id) ON DELETE SET NULL;


-- RLS Policies for new tables and features.

-- FIX: Create a SECURITY DEFINER function to break the recursion
CREATE OR REPLACE FUNCTION is_collaborator(board_id_to_check int, user_id_to_check uuid)
RETURNS boolean AS $$
BEGIN
  -- This function runs as the user who defined it (superuser), bypassing RLS.
  -- It safely checks for collaboration without re-querying the 'boards' table in a recursive way.
  RETURN EXISTS (
    SELECT 1
    FROM public.board_collaborators
    WHERE board_id = board_id_to_check AND user_id = user_id_to_check
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- FIX: Drop all old SELECT policies and create a new, unified one
DROP POLICY IF EXISTS "Enable read access for all users" ON public.boards;
DROP POLICY IF EXISTS "Enable read access for user's own boards and public boards" ON public.boards;
DROP POLICY IF EXISTS "Enable read access for collaborators" ON public.boards;
DROP POLICY IF EXISTS "Users can view own boards" ON public.boards;


-- FIX: A single, combined policy for reading boards that uses the new function
CREATE POLICY "Enable read access for boards" ON public.boards
FOR SELECT
USING (
    auth.uid() = user_id OR -- User is the owner
    is_secret = FALSE OR -- Board is public
    is_collaborator(id, auth.uid()) -- User is a collaborator
);


-- RLS for board_collaborators table (this policy is now safe because the recursion is broken)
ALTER TABLE public.board_collaborators ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow owner to manage collaborators" ON public.board_collaborators
FOR ALL
USING (
    (SELECT user_id FROM public.boards WHERE id = board_id) = auth.uid()
);

CREATE POLICY "Allow collaborators to view their own collaboration" ON public.board_collaborators
FOR SELECT
USING (
    user_id = auth.uid()
);


-- RLS for board_sections table
ALTER TABLE public.board_sections ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow board owner and collaborators to manage sections" ON public.board_sections
FOR ALL
USING (
    (SELECT user_id FROM public.boards WHERE id = board_id) = auth.uid() OR
    is_collaborator(board_id, auth.uid())
);