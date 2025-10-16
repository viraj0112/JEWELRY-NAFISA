CREATE POLICY "Admins can view all user profiles"
ON public.users FOR SELECT
TO authenticated
USING (
  (SELECT role FROM public.users WHERE id = auth.uid()) = 'admin'
);