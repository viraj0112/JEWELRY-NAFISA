CREATE TABLE public.pending_signup_uploads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  signup_id UUID NOT NULL,
  email TEXT NOT NULL,
  file_type TEXT NOT NULL,
  file_ext TEXT NOT NULL,
  object_path TEXT NOT NULL,
  mime_type TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  linked_user_id UUID REFERENCES public.users(id),
  linked_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX pending_signup_uploads_signup_id_idx
  ON public.pending_signup_uploads (signup_id);

CREATE INDEX pending_signup_uploads_email_idx
  ON public.pending_signup_uploads (email);

ALTER TABLE public.pending_signup_uploads ENABLE ROW LEVEL SECURITY;
