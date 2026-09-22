-- Make redeem_quote_credit atomic.
--
-- THE BUG: the previous version did
--     SELECT credits_remaining INTO v_credits_remaining FROM users WHERE id = uid;
--     IF v_credits_remaining < v_deduction_amount THEN ... reject ... END IF;
--     UPDATE users SET credits_remaining = credits_remaining - v_deduction_amount ...
--
-- Under READ COMMITTED (Postgres' default) two concurrent calls both read the
-- same starting balance, both pass the sufficiency check, and both then apply
-- their decrement. A user with 5 credits who fires two requests at once spends
-- 10 and lands on -5 — free quotes, and a negative balance the UI never
-- expects. SECURITY DEFINER does not serialise anything, and neither does
-- being inside one plpgsql function: it is the read-then-write gap that is
-- unsafe, not the number of statements.
--
-- THE FIX: fold the check into the UPDATE itself. `WHERE credits_remaining >=
-- v_deduction_amount` is evaluated against the row the UPDATE actually locks,
-- so a concurrent transaction that got there first is seen. When the guard
-- fails no row matches, NOT FOUND is set, and we reject without writing.
--
-- Signature is unchanged so existing callers keep working.
-- NOTE: p_is_designer remains unused — `quotes` has no column recording which
-- product table the id refers to, so `products#42` and `designerproducts#42`
-- are still indistinguishable. Tracked separately; adding the column is a
-- schema change, not a concurrency fix.

CREATE OR REPLACE FUNCTION public.redeem_quote_credit(
  p_product_id TEXT,
  p_is_designer BOOLEAN
)
RETURNS JSONB AS $$
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

  -- How many credits a reveal costs, per system settings.
  SELECT COALESCE(
    (SELECT value::INT FROM public.settings WHERE key = 'credit_deduction_amount'),
    5
  ) INTO v_deduction_amount;

  -- Check and deduct in one statement. RETURNING gives us the post-deduction
  -- balance without a second read that could itself be stale.
  UPDATE public.users
     SET credits_remaining = credits_remaining - v_deduction_amount
   WHERE id = v_user_id
     AND credits_remaining >= v_deduction_amount
  RETURNING credits_remaining INTO v_credits_after;

  -- No row updated => either the user does not exist or the balance was too
  -- low by the time we held the lock. Nothing was written.
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient credits');
  END IF;

  INSERT INTO public.quotes (user_id, product_id, status, expires_at)
  VALUES (v_user_id, p_product_id, 'valid', NOW() + INTERVAL '30 days')
  RETURNING id INTO v_quote_id;

  RETURN jsonb_build_object(
    'success', true,
    'quote_id', v_quote_id,
    'credits_remaining', v_credits_after,
    'deducted_amount', v_deduction_amount
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.redeem_quote_credit(TEXT, BOOLEAN) TO authenticated;

-- Backstop: even if some other code path ever decrements directly, the balance
-- can no longer go negative. Added NOT VALID so the migration cannot fail on
-- rows an earlier race already drove below zero; clean those up, then run
--   ALTER TABLE public.users VALIDATE CONSTRAINT users_credits_remaining_non_negative;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'users_credits_remaining_non_negative'
      AND conrelid = 'public.users'::regclass
  ) THEN
    ALTER TABLE public.users
      ADD CONSTRAINT users_credits_remaining_non_negative
      CHECK (credits_remaining >= 0) NOT VALID;
  END IF;
END $$;
