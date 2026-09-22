-- ============================================================================
-- Three schema fixes: the views table, the quotes discriminator, and the
-- credential view's security mode.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. public.views - reconcile the migration-built shape with production.
--
-- 20251016120002 creates views as:
--     (id, created_at, user_id, pin_id uuid, product_id bigint, country)
--   + CONSTRAINT chk_view_link CHECK (exactly one of pin_id / product_id)
--
-- Production is a completely different, polymorphic table:
--     (id, created_at, user_id, country, item_id text, item_table text,
--      state, pincode, item_uid uuid)
--
-- Consequences of the drift:
--   * a database built from migrations cannot record a view the app can read
--     back - every analytics RPC filters on item_id/item_table;
--   * views on `products` and `manufacturerproducts` were impossible even in
--     principle, because product_id had a foreign key to designerproducts only;
--   * the log-view-with-geo edge function (rewritten to insert item_id /
--     item_table) would fail against a migration-built database.
--
-- Everything below is written so it is a no-op on production, where these
-- columns already exist and the constraint never did.
-- ----------------------------------------------------------------------------
ALTER TABLE public.views ADD COLUMN IF NOT EXISTS item_id    text;
ALTER TABLE public.views ADD COLUMN IF NOT EXISTS item_table text;
ALTER TABLE public.views ADD COLUMN IF NOT EXISTS item_uid   uuid;
ALTER TABLE public.views ADD COLUMN IF NOT EXISTS state      text;
ALTER TABLE public.views ADD COLUMN IF NOT EXISTS pincode    text;

-- The CHECK demanded exactly one of pin_id/product_id, so a polymorphic row
-- (both null, keyed by item_id/item_table) could never be inserted.
ALTER TABLE public.views DROP CONSTRAINT IF EXISTS chk_view_link;

-- pin_id / product_id are NOT dropped here. They may still hold historical
-- rows, and dropping columns is the kind of thing that belongs in its own
-- reviewed migration rather than riding along with a compatibility fix.

CREATE INDEX IF NOT EXISTS idx_views_item
  ON public.views (item_table, item_id);


-- ----------------------------------------------------------------------------
-- 2. public.quotes - record WHICH table product_id refers to.
--
-- redeem_quote_credit(p_product_id, p_is_designer) has always accepted
-- p_is_designer and never used it: the quotes row stores a bare product_id, so
-- products#42, designerproducts#42 and manufacturerproducts#42 are
-- indistinguishable after the fact. Anything joining quotes back to a catalog
-- row is guessing.
--
-- Add the discriminator, then teach the function to write it.
-- ----------------------------------------------------------------------------
ALTER TABLE public.quotes
  ADD COLUMN IF NOT EXISTS product_table text;

COMMENT ON COLUMN public.quotes.product_table IS
  'Which catalog table product_id refers to: products | designerproducts | manufacturerproducts. Null on rows created before 2026-09-19, which are unattributable.';

CREATE OR REPLACE FUNCTION public.redeem_quote_credit(
  p_product_id TEXT,
  p_is_designer BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_user_id UUID;
  v_deduction_amount INT;
  v_credits_after INT;
  v_quote_id UUID;
BEGIN
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not authenticated');
  END IF;

  SELECT COALESCE(
    (SELECT value::INT FROM public.settings WHERE key = 'credit_deduction_amount'),
    5
  ) INTO v_deduction_amount;

  -- Check and deduct in ONE statement: see 20260919000000 for why a
  -- read-then-write here let two concurrent calls both pass the balance check.
  UPDATE public.users
     SET credits_remaining = credits_remaining - v_deduction_amount
   WHERE id = v_user_id
     AND credits_remaining >= v_deduction_amount
  RETURNING credits_remaining INTO v_credits_after;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient credits');
  END IF;

  INSERT INTO public.quotes (user_id, product_id, product_table, status, expires_at)
  VALUES (
    v_user_id,
    p_product_id,
    -- p_is_designer is finally load-bearing. It is a boolean, so it cannot
    -- distinguish manufacturer products; callers that know better should be
    -- moved to a table-name parameter, but this is strictly better than
    -- recording nothing.
    CASE WHEN p_is_designer THEN 'designerproducts' ELSE 'products' END,
    'valid',
    NOW() + INTERVAL '30 days'
  )
  RETURNING id INTO v_quote_id;

  RETURN jsonb_build_object(
    'success', true,
    'quote_id', v_quote_id,
    'credits_remaining', v_credits_after,
    'deducted_amount', v_deduction_amount
  );
END;
$fn$;

REVOKE EXECUTE ON FUNCTION public.redeem_quote_credit(TEXT, BOOLEAN) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.redeem_quote_credit(TEXT, BOOLEAN) TO authenticated;


-- ----------------------------------------------------------------------------
-- 3. api_credential_status - restore the definer view.
--
-- Timeline:
--   20260729120000  revoked table-level SELECT on api_credentials from
--                   `authenticated` (to hide the encrypted key columns) and
--                   created this view with security_invoker = true.
--   20260730140000  set security_invoker = false, explicitly, because an
--                   invoker view on a table the caller has no table-level
--                   SELECT on raises 42501 - PostgreSQL needs that privilege
--                   to evaluate RLS at all. Its header even warned what would
--                   happen if this were ever reverted.
--   20260826001000  set security_invoker = true again, to stop Supabase
--                   Advisor flagging it as a SECURITY DEFINER view. The
--                   comment there claims these views "rely on the underlying
--                   table RLS policies" - which is exactly the assumption
--                   20260729120000 had already made false.
--
-- Advisor is warning about a real pattern, but the mitigation it wants is not
-- available here: the view's own WHERE clause IS the access control, it
-- selects no secret column, and the browser still has no table-level grant.
-- ----------------------------------------------------------------------------
ALTER VIEW public.api_credential_status SET (security_invoker = false);

-- Restated so a future invoker flip degrades to "reads the safe columns"
-- rather than 42501. Idempotent.
GRANT SELECT (
  user_id, llm_model, llm_key_hint, is_active, key_prefix,
  expires_at, last_used_at, created_at, updated_at
) ON public.api_credentials TO authenticated;
GRANT UPDATE (llm_model) ON public.api_credentials TO authenticated;

GRANT SELECT ON public.api_credential_status TO authenticated, service_role;
GRANT UPDATE (llm_model) ON public.api_credential_status TO authenticated;


-- ----------------------------------------------------------------------------
-- Verification:
--
--   -- 1. views now takes a polymorphic row:
--   SELECT column_name FROM information_schema.columns
--    WHERE table_name = 'views' AND column_name IN
--          ('item_id','item_table','item_uid','state','pincode');
--
--   -- 2. new quotes carry their source table:
--   SELECT product_table, count(*) FROM public.quotes GROUP BY 1;
--
--   -- 3. the credential view is a definer view again (expect reloptions to be
--   --    null, or to not contain security_invoker=true):
--   SELECT relname, reloptions FROM pg_class
--    WHERE relname = 'api_credential_status';
-- ----------------------------------------------------------------------------
