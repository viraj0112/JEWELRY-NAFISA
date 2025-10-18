-- Create the table for designer-specific profile information
CREATE TABLE public.designer_profiles (
  -- This links directly to the main users table
  user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,

  -- Business Information
  business_name TEXT NOT NULL,
  business_type public.designer_role_type, -- Uses the custom type for consistency
  phone TEXT,
  address TEXT,
  gst_number TEXT, -- Optional field

  -- Links to Uploaded Files
  -- Storing URLs is better than storing the files directly in the database
  work_file_url TEXT,
  business_card_url TEXT,

  -- Timestamps for record-keeping
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add a comment to explain the table's purpose
COMMENT ON TABLE public.designer_profiles IS 'Stores profile information specific to designers, extending the base user table.';