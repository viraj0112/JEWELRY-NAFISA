-- Create function to redeem a quote credit
-- This function checks if user has credits, decrements credit, and creates a quote record
CREATE OR REPLACE FUNCTION public.redeem_quote_credit(
  p_product_id TEXT,
  p_is_designer BOOLEAN
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID;
  v_credits_remaining INT;
  v_quote_id UUID;
BEGIN
  -- Get the current user ID
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not authenticated');
  END IF;

  -- Check if user has credits
  SELECT credits_remaining INTO v_credits_remaining
  FROM public.users
  WHERE id = v_user_id;

  IF v_credits_remaining IS NULL OR v_credits_remaining <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient credits');
  END IF;

  -- Decrement credit
  UPDATE public.users
  SET credits_remaining = credits_remaining - 1
  WHERE id = v_user_id;

  -- Create quote record (valid for 30 days)
  INSERT INTO public.quotes (
    user_id,
    product_id,
    status,
    expires_at
  )
  VALUES (
    v_user_id,
    p_product_id,
    'valid',
    NOW() + INTERVAL '30 days'
  )
  RETURNING id INTO v_quote_id;

  -- Return success response
  RETURN jsonb_build_object(
    'success', true,
    'quote_id', v_quote_id,
    'credits_remaining', v_credits_remaining - 1
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.redeem_quote_credit(TEXT, BOOLEAN) TO authenticated;

