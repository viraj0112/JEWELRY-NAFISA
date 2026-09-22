-- ============================================================================
-- ADDITIVE: b2b_sync_history — audit log for the B2B "Edit in Sheets" CSV
-- sync workflow. Safe to run any time (no drops, no renames, no rewrites);
-- independent of the Phase 3 contract migration.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.b2b_sync_history (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  table_name text NOT NULL CHECK (table_name IN ('designerproducts', 'manufacturerproducts')),
  file_name text NOT NULL DEFAULT 'unknown.csv',
  updated_count integer NOT NULL DEFAULT 0,
  inserted_count integer NOT NULL DEFAULT 0,
  skipped_count integer NOT NULL DEFAULT 0,
  failed_count integer NOT NULL DEFAULT 0,
  error_details jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_b2b_sync_history_user
  ON public.b2b_sync_history (user_id, table_name, created_at DESC);

ALTER TABLE public.b2b_sync_history ENABLE ROW LEVEL SECURITY;

-- Users see and write only their own history rows.
DROP POLICY IF EXISTS "b2b_sync_history_select_own" ON public.b2b_sync_history;
CREATE POLICY "b2b_sync_history_select_own" ON public.b2b_sync_history
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "b2b_sync_history_insert_own" ON public.b2b_sync_history;
CREATE POLICY "b2b_sync_history_insert_own" ON public.b2b_sync_history
  FOR INSERT WITH CHECK (auth.uid() = user_id);

GRANT SELECT, INSERT ON public.b2b_sync_history TO authenticated;
