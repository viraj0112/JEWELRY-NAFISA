-- Function to increment like count
CREATE OR REPLACE FUNCTION increment_like_count(pin_id_to_update UUID, delta INTEGER)
RETURNS VOID AS $$
BEGIN
  UPDATE pins 
  SET like_count = like_count + delta 
  WHERE id = pin_id_to_update;
END;
$$ LANGUAGE plpgsql 
-- ADD THESE TWO LINES
SECURITY DEFINER 
SET search_path = public;

-- Function to decrement credit (for membership feature)
CREATE OR REPLACE FUNCTION decrement_credit()
RETURNS VOID AS $$
DECLARE
  user_id UUID;
BEGIN
  user_id := auth.uid();
  UPDATE users 
  SET credits_remaining = credits_remaining - 1 
  WHERE id = user_id AND credits_remaining > 0;
END;
$$ LANGUAGE plpgsql 
-- ADD THESE TWO LINES
SECURITY DEFINER 
SET search_path = public;

-- Create RPC functions for the jewelry app

-- Function to generate a unique share slug
CREATE OR REPLACE FUNCTION gen_share_slug()
RETURNS TEXT AS $$
DECLARE
  new_slug TEXT;
  slug_exists BOOLEAN := TRUE;
BEGIN
  WHILE slug_exists LOOP
    -- Generate a random 8-character slug
    new_slug := substring(replace(gen_random_uuid()::text, '-', ''), 1, 8);
    
    -- Check if this slug already exists
    SELECT EXISTS (
      SELECT 1 FROM pins WHERE share_slug = new_slug
    ) INTO slug_exists;
  END LOOP;
  
  RETURN new_slug;
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public;

-- Function to increment like count
CREATE OR REPLACE FUNCTION increment_like_count(pin_id_to_update UUID, delta INTEGER)
RETURNS VOID AS $$
BEGIN
  UPDATE pins 
  SET like_count = like_count + delta 
  WHERE id = pin_id_to_update;
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public;

-- Function to decrement credit (for membership feature)
CREATE OR REPLACE FUNCTION decrement_credit()
RETURNS VOID AS $$
DECLARE
  user_id UUID;
BEGIN
  -- Get the current user ID
  user_id := auth.uid();
  
  -- Decrement the user's credit count
  UPDATE users 
  SET credits_remaining = credits_remaining - 1 
  WHERE id = user_id AND credits_remaining > 0;
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public;