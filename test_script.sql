CREATE TABLE public.test_table (
  id serial primary key,
  secret text,
  public_col text
);
INSERT INTO public.test_table (secret, public_col) VALUES ('hidden', 'visible');
CREATE ROLE test_user;
GRANT USAGE ON SCHEMA public TO test_user;
REVOKE ALL ON public.test_table FROM test_user;
GRANT SELECT (id, public_col) ON public.test_table TO test_user;
CREATE OR REPLACE VIEW public.test_view WITH (security_invoker = true) AS
SELECT id, public_col FROM public.test_table;
GRANT SELECT ON public.test_view TO test_user;
SET ROLE test_user;
SELECT * FROM public.test_view;
