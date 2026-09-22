-- ============================================================================
-- Send a shared secret with the dashboard-update webhook
-- ----------------------------------------------------------------------------
-- handle_dashboard_update() posted to the dashboard-update edge function with
-- only a Content-Type header:
--
--     PERFORM net.http_post(url, body, '{}'::jsonb,
--                           '{"Content-Type": "application/json"}'::jsonb);
--
-- so the endpoint had no way to tell the trigger apart from any anonymous
-- caller on the internet - and it broadcast whatever `record` it was handed to
-- every admin watching the realtime channel.
--
-- The function now requires `x-dashboard-secret`. This sends it, reading the
-- value from Vault so the secret is never written into a migration file.
--
-- SETUP (both sides must carry the same value):
--     openssl rand -hex 32
--     supabase secrets set DASHBOARD_UPDATE_SECRET=<value>
--     select vault.create_secret('<value>', 'dashboard_update_secret');
--
-- Until that is done the function returns 503/403 and live dashboard updates
-- stop. Fixing that is a matter of setting the secret, not of reverting this.
--
-- Also fixed here: the project URL was hardcoded in the function body. It now
-- comes from the same Vault, so a restore into another project does not post
-- production traffic at the old one.
--     select vault.create_secret('https://<ref>.supabase.co', 'project_url');
-- (falls back to the previous literal if that secret is absent).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.handle_dashboard_update()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, vault
AS $fn$
DECLARE
  v_secret text;
  v_base   text;
BEGIN
  SELECT decrypted_secret INTO v_secret
    FROM vault.decrypted_secrets
   WHERE name = 'dashboard_update_secret'
   LIMIT 1;

  SELECT decrypted_secret INTO v_base
    FROM vault.decrypted_secrets
   WHERE name = 'project_url'
   LIMIT 1;

  v_base := COALESCE(v_base, 'https://cxnkagfbymztpwszfaiw.supabase.co');

  -- No secret configured yet: skip the call rather than firing an
  -- unauthenticated request the function will reject anyway. The trigger must
  -- never break the write it is attached to.
  IF v_secret IS NULL THEN
    RAISE WARNING 'dashboard_update_secret not set in Vault; skipping dashboard broadcast.';
    RETURN NEW;
  END IF;

  PERFORM net.http_post(
    v_base || '/functions/v1/dashboard-update',
    json_build_object('record', NEW)::text,
    '{}'::jsonb,
    jsonb_build_object(
      'Content-Type', 'application/json',
      'x-dashboard-secret', v_secret
    )
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- A dashboard broadcast is best-effort telemetry. It must not roll back the
  -- user-facing INSERT/UPDATE that fired this trigger.
  RAISE WARNING 'dashboard-update webhook failed: %', SQLERRM;
  RETURN NEW;
END;
$fn$;
