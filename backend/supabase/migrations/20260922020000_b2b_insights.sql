-- ============================================================================
-- b2b_insights(): one aggregated performance report for a seller's products
-- ----------------------------------------------------------------------------
-- Powers the B2B "Insights" tab and the per-product "View Insights" sheet.
-- Before this, the app counted raw event rows client-side: saves were read
-- from a table that doesn't exist (always 0), growth figures were hardcoded,
-- quote requests (private to the requester) couldn't be seen at all, and the
-- "insight" line was fixed text.
--
-- Returns aggregates only - never viewer ids - for the CALLER's own products
-- (admins / service_role may pass p_owner). Locations resolve the event's
-- pincode (via pincode_regions, as get_geo_analytics_batch does), else the
-- event's recorded state, else the viewer's profile pincode, else country.
--
-- Periods: "totals" cover [p_from, p_to) - all time when p_from is null.
-- "current" is the selected range (or the last 30 days when none) and
-- "previous" the equally long window just before it, for real change %.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.b2b_insights(
  p_table   text,
  p_from    timestamptz DEFAULT NULL,
  p_to      timestamptz DEFAULT NULL,
  p_item_id bigint      DEFAULT NULL,
  p_owner   uuid        DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_owner    uuid := auth.uid();
  v_products jsonb;
  v_ids      text[];
  v_to       timestamptz := coalesce(p_to, now());
  v_from     timestamptz;
  v_len      interval;
  v_result   jsonb;
BEGIN
  IF p_table NOT IN ('products', 'designerproducts', 'manufacturerproducts') THEN
    RAISE EXCEPTION 'Unknown product table %', p_table;
  END IF;

  -- Only admins / the service role may look at someone else's catalogue.
  IF p_owner IS NOT NULL AND p_owner IS DISTINCT FROM v_owner THEN
    IF NOT (coalesce(auth.role(), '') = 'service_role' OR public.is_admin()) THEN
      RAISE EXCEPTION 'Not allowed';
    END IF;
    v_owner := p_owner;
  END IF;
  IF v_owner IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- The owner's products (id -> title, first image, upload date).
  EXECUTE format($q$
    SELECT coalesce(jsonb_object_agg(id::text, jsonb_build_object(
             'title', "Product Title",
             'image', ("Images")[1],
             'created_at', created_at)), '{}'::jsonb)
    FROM public.%I
    WHERE user_id = $1 AND ($2::bigint IS NULL OR id = $2)
  $q$, p_table)
  INTO v_products
  USING v_owner, p_item_id;

  v_ids := ARRAY(SELECT jsonb_object_keys(v_products));
  IF p_item_id IS NOT NULL AND cardinality(v_ids) = 0 THEN
    RAISE EXCEPTION 'Product not found';
  END IF;

  v_from := coalesce(p_from, v_to - interval '30 days');
  v_len  := v_to - v_from;

  WITH ev AS (
    SELECT 'view'::text AS kind, v.item_id, v.created_at, v.user_id,
           v.pincode, v.state, v.country
      FROM views v
     WHERE v.item_table = p_table AND v.item_id = ANY (v_ids)
    UNION ALL
    SELECT 'like', l.item_id, l.created_at, l.user_id, l.pincode, l.state, l.country
      FROM likes l
     WHERE l.item_table = p_table AND l.item_id = ANY (v_ids)
    UNION ALL
    SELECT 'share', s.item_id, s.created_at, s.user_id, NULL, NULL, NULL
      FROM shares s
     WHERE s.item_table = p_table AND s.item_id = ANY (v_ids)
    UNION ALL
    SELECT 'save', sv.item_id, sv.created_at, sv.user_id, sv.pincode, sv.state, sv.country
      FROM saves sv
     WHERE sv.item_table = p_table AND sv.item_id = ANY (v_ids)
    UNION ALL
    SELECT 'quote', q.product_id::text, q.created_at, q.user_id, NULL, NULL, NULL
      FROM quote_requests q
     WHERE q.product_table = p_table AND q.product_id::text = ANY (v_ids)
  ),
  located AS (
    SELECT ev.*,
           -- Where the event happened beats where the viewer lives: the
           -- event's pincode, then its state, then the profile pincode.
           coalesce(
             (SELECT concat_ws(', ', nullif(pr.district, ''), pr.state)
                FROM pincode_regions pr
               WHERE pr.pincode = ev.pincode
               LIMIT 1),
             nullif(ev.state, ''),
             (SELECT concat_ws(', ', nullif(pr.district, ''), pr.state)
                FROM users u
                JOIN pincode_regions pr ON pr.pincode = u.zip_code
               WHERE u.id = ev.user_id
               LIMIT 1),
             nullif(ev.country, '')
           ) AS location
      FROM ev
  ),
  scoped AS (
    SELECT * FROM located
     WHERE (p_from IS NULL OR created_at >= p_from)
       AND (p_to   IS NULL OR created_at <  p_to)
  )
  SELECT jsonb_build_object(
    'product_count', cardinality(v_ids),
    'window', jsonb_build_object('from', v_from, 'to', v_to),

    'totals', (
      SELECT jsonb_build_object(
        'views',          count(*) FILTER (WHERE kind = 'view'),
        'unique_viewers', count(DISTINCT user_id) FILTER (WHERE kind = 'view'),
        'likes',          count(*) FILTER (WHERE kind = 'like'),
        'shares',         count(*) FILTER (WHERE kind = 'share'),
        'saves',          count(*) FILTER (WHERE kind = 'save'),
        'quote_requests', count(*) FILTER (WHERE kind = 'quote'))
      FROM scoped),

    'current', (
      SELECT jsonb_build_object(
        'views',          count(*) FILTER (WHERE kind = 'view'),
        'likes',          count(*) FILTER (WHERE kind = 'like'),
        'shares',         count(*) FILTER (WHERE kind = 'share'),
        'saves',          count(*) FILTER (WHERE kind = 'save'),
        'quote_requests', count(*) FILTER (WHERE kind = 'quote'))
      FROM located
      WHERE created_at >= v_from AND created_at < v_to),

    'previous', (
      SELECT jsonb_build_object(
        'views',          count(*) FILTER (WHERE kind = 'view'),
        'likes',          count(*) FILTER (WHERE kind = 'like'),
        'shares',         count(*) FILTER (WHERE kind = 'share'),
        'saves',          count(*) FILTER (WHERE kind = 'save'),
        'quote_requests', count(*) FILTER (WHERE kind = 'quote'))
      FROM located
      WHERE created_at >= v_from - v_len AND created_at < v_from),

    -- One point per day of the current window (capped at a year).
    'daily_views', (
      SELECT coalesce(jsonb_agg(
               jsonb_build_object('day', d::date, 'views', coalesce(c.n, 0))
               ORDER BY d), '[]'::jsonb)
      FROM generate_series(
             date_trunc('day', greatest(v_from, v_to - interval '366 days')),
             date_trunc('day', v_to),
             interval '1 day') AS d
      LEFT JOIN (
        SELECT date_trunc('day', created_at) AS day, count(*) AS n
          FROM located
         WHERE kind = 'view' AND created_at >= v_from AND created_at < v_to
         GROUP BY 1
      ) c ON c.day = d),

    'top_locations', (
      SELECT coalesce(jsonb_agg(t.x ORDER BY (t.x->>'count')::int DESC), '[]'::jsonb)
      FROM (
        SELECT jsonb_build_object('location', location, 'count', count(*)) AS x
          FROM scoped
         WHERE location IS NOT NULL AND kind IN ('view', 'like', 'save')
         GROUP BY location
         ORDER BY count(*) DESC
         LIMIT 8
      ) t),

    'top_products', (
      SELECT coalesce(jsonb_agg(t.p ORDER BY (t.p->>'score')::int DESC), '[]'::jsonb)
      FROM (
        SELECT jsonb_build_object(
                 'id', item_id,
                 'title', v_products -> item_id ->> 'title',
                 'image', v_products -> item_id ->> 'image',
                 'views',          count(*) FILTER (WHERE kind = 'view'),
                 'likes',          count(*) FILTER (WHERE kind = 'like'),
                 'shares',         count(*) FILTER (WHERE kind = 'share'),
                 'saves',          count(*) FILTER (WHERE kind = 'save'),
                 'quote_requests', count(*) FILTER (WHERE kind = 'quote'),
                 -- Quote requests signal buying intent, so they weigh most.
                 'score', count(*) FILTER (WHERE kind = 'view')
                        + 3 * count(*) FILTER (WHERE kind IN ('like', 'save', 'share'))
                        + 10 * count(*) FILTER (WHERE kind = 'quote')) AS p
          FROM scoped
         GROUP BY item_id
         ORDER BY count(*) FILTER (WHERE kind = 'view')
                + 3 * count(*) FILTER (WHERE kind IN ('like', 'save', 'share'))
                + 10 * count(*) FILTER (WHERE kind = 'quote') DESC
         LIMIT 5
      ) t),

    'recent_activity', (
      SELECT coalesce(jsonb_agg(t.a ORDER BY t.at DESC), '[]'::jsonb)
      FROM (
        SELECT created_at AS at,
               jsonb_build_object(
                 'kind', kind,
                 'item_id', item_id,
                 'title', v_products -> item_id ->> 'title',
                 'at', created_at,
                 'location', location) AS a
          FROM scoped
         ORDER BY created_at DESC
         LIMIT 12
      ) t)
  )
  INTO v_result;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.b2b_insights(text, timestamptz, timestamptz, bigint, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.b2b_insights(text, timestamptz, timestamptz, bigint, uuid)
  TO authenticated, service_role;
