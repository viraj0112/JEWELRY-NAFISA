CREATE OR REPLACE FUNCTION handle_dashboard_update()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM net.http_post(
    'https://wkwygcnvpzxzzlxjaqff.supabase.co/functions/v1/dashboard-update', 
    json_build_object('record', NEW)::text,
    '{}'::jsonb,
    '{"Content-Type": "application/json"}'::jsonb
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
