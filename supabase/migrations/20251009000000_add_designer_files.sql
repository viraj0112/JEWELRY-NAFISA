-- Add address and GST number columns to the users table
ALTER TABLE public.users
ADD COLUMN address TEXT,
ADD COLUMN gst_number TEXT;

-- Create a table to store designer-specific files
CREATE TABLE public.designer-files (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    file_type TEXT NOT NULL, -- 'work_file' or 'business_card'
    file_url TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security for the new table
ALTER TABLE public.designer-files ENABLE ROW LEVEL SECURITY;

-- Add policies for the designer-files table
CREATE POLICY "Designers can manage their own files"
ON public.designer-files
FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins have full access to designer files"
ON public.designer-files
FOR ALL
USING (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin'::user_role));