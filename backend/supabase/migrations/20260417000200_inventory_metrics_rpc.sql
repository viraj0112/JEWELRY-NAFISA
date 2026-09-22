CREATE OR REPLACE FUNCTION search_inventory_with_metrics(
  p_table_filter text DEFAULT 'all',
  p_search_term text DEFAULT '',
  p_min_likes int DEFAULT 0,
  p_min_views int DEFAULT 0,
  p_min_shares int DEFAULT 0,
  p_min_credits int DEFAULT 0,
  p_product_type text DEFAULT NULL,
  p_start_date timestamp with time zone DEFAULT NULL,
  p_end_date timestamp with time zone DEFAULT NULL,
  p_limit int DEFAULT 100
) RETURNS TABLE (
  id text,
  title text,
  category text,
  status text,
  source text,
  thumb_url text,
  media_url text,
  owner_id uuid,
  created_at timestamp with time zone,
  product_type text,
  likes_count bigint,
  views_count bigint,
  shares_count bigint,
  credits_used bigint
) LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  WITH all_items AS (
    SELECT 
      p.id::text as id, 
      p."Product Title" as title, 
      p."Category" as category, 
      'uploaded' as status, 
      'products' as source, 
      COALESCE((p."Image")[1], p."Images") as thumb_url, 
      COALESCE((p."Image")[1], p."Images") as media_url, 
      p.user_id as owner_id, 
      NULL::timestamp with time zone as created_at,
      p."Product Type" as product_type
    FROM products p
    WHERE (p_table_filter = 'all' OR p_table_filter = 'products')

    UNION ALL

    SELECT 
      d.id::text as id, 
      d."Product Title", 
      d."Category", 
      'uploaded', 
      'designerproducts', 
      (d."Image")[1], 
      (d."Image")[1], 
      d.user_id, 
      d.created_at,
      d."Product Type"
    FROM designerproducts d
    WHERE (p_table_filter = 'all' OR p_table_filter = 'designerproducts')

    UNION ALL

    SELECT 
      m.id::text as id, 
      m."Product Title", 
      m."Category", 
      'uploaded', 
      'manufacturerproducts', 
      (m."Image")[1], 
      (m."Image")[1], 
      m.user_id, 
      m.created_at,
      m."Product Type"
    FROM manufacturerproducts m
    WHERE (p_table_filter = 'all' OR p_table_filter = 'manufacturerproducts')
  ),
  filtered_items AS (
    SELECT * FROM all_items
    WHERE (p_search_term = '' OR title ILIKE '%' || p_search_term || '%')
    AND (p_product_type IS NULL OR p_product_type = '' OR product_type ILIKE '%' || p_product_type || '%')
  ),
  metrics AS (
    SELECT 
      fi.id,
      fi.title,
      fi.category,
      fi.status,
      fi.source,
      fi.thumb_url,
      fi.media_url,
      fi.owner_id,
      fi.created_at,
      fi.product_type,
      (SELECT COUNT(*) FROM likes l WHERE l.item_id = fi.id AND l.item_table = fi.source AND (p_start_date IS NULL OR l.created_at >= p_start_date) AND (p_end_date IS NULL OR l.created_at <= p_end_date)) as likes_count,
      (SELECT COUNT(*) FROM views v WHERE v.item_id = fi.id AND v.item_table = fi.source AND (p_start_date IS NULL OR v.created_at >= p_start_date) AND (p_end_date IS NULL OR v.created_at <= p_end_date)) as views_count,
      (SELECT COUNT(*) FROM shares s WHERE s.item_id = fi.id AND s.item_table = fi.source AND (p_start_date IS NULL OR s.created_at >= p_start_date) AND (p_end_date IS NULL OR s.created_at <= p_end_date)) as shares_count,
      (SELECT COUNT(*) FROM user_unlocked_items u WHERE u.item_id = fi.id AND (p_start_date IS NULL OR u.unlocked_at >= p_start_date) AND (p_end_date IS NULL OR u.unlocked_at <= p_end_date)) as credits_used
    FROM filtered_items fi
  )
  SELECT * FROM metrics 
  WHERE likes_count >= p_min_likes 
    AND views_count >= p_min_views 
    AND shares_count >= p_min_shares 
    AND credits_used >= p_min_credits
  ORDER BY created_at DESC NULLS LAST
  LIMIT p_limit;
END;
$$;
