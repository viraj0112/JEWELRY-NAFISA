-- ============================================================================
-- RLS GAP FIX — pre-existing issues, unrelated to the Phase 3 rename.
-- ----------------------------------------------------------------------------
-- Audit found:
--   1. products, views, saves have policies defined (or, for saves, none) but
--      row_security is DISABLED on the table itself, so every policy is dead
--      and the table is fully open to anon/authenticated.
--   2. saves has zero policies at all.
--   3. products/designerproducts/manufacturerproducts have no admin bypass,
--      unlike assets — admin dashboard writes only work via service_role.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Enable RLS where it was off.
-- ----------------------------------------------------------------------------
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.views ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.saves ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- 2. saves — same shape as views/likes: public read, owner-only write.
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Public can read saves" ON public.saves;
CREATE POLICY "Public can read saves" ON public.saves
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert their own saves" ON public.saves;
CREATE POLICY "Users can insert their own saves" ON public.saves
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own saves" ON public.saves;
CREATE POLICY "Users can delete their own saves" ON public.saves
  FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

-- ----------------------------------------------------------------------------
-- 3. Admin bypass on the three product tables (matches assets' pattern).
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Admins have full access" ON public.products;
CREATE POLICY "Admins have full access" ON public.products
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.users WHERE users.id = auth.uid() AND users.role = 'admin'::user_role)
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM public.users WHERE users.id = auth.uid() AND users.role = 'admin'::user_role)
  );

DROP POLICY IF EXISTS "Admins have full access" ON public.designerproducts;
CREATE POLICY "Admins have full access" ON public.designerproducts
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.users WHERE users.id = auth.uid() AND users.role = 'admin'::user_role)
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM public.users WHERE users.id = auth.uid() AND users.role = 'admin'::user_role)
  );

DROP POLICY IF EXISTS "Admins have full access" ON public.manufacturerproducts;
CREATE POLICY "Admins have full access" ON public.manufacturerproducts
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.users WHERE users.id = auth.uid() AND users.role = 'admin'::user_role)
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM public.users WHERE users.id = auth.uid() AND users.role = 'admin'::user_role)
  );
