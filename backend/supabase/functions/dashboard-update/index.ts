import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Fans a changed row out to the `dashboard` realtime channel so open admin
// dashboards update live. Invoked by the handle_dashboard_update() trigger.
//
// SECURITY: this had no authentication of any kind. The trigger calls it with
// only a Content-Type header, so the endpoint accepted `{record}` from anyone
// and broadcast it verbatim to every admin watching the channel - arbitrary
// fabricated metrics injected into the admin UI by any anonymous caller.
//
// It also built its client with the anon key while overriding the
// Authorization header with the SERVICE ROLE key, which is a confusing way to
// end up with full service-role access; the client is now constructed with the
// service-role key directly.
//
// The trigger is database-side, so there is no user JWT to check. Instead both
// sides share a secret:
//
//   1. openssl rand -hex 32
//   2. supabase secrets set DASHBOARD_UPDATE_SECRET=<that value>
//   3. In the SQL editor, store the SAME value for the trigger to send:
//        select vault.create_secret('<that value>', 'dashboard_update_secret');
//      (to rotate later: select vault.update_secret(id, '<new value>') )
//
// FAILS CLOSED: until DASHBOARD_UPDATE_SECRET is set, every call is rejected
// and live dashboard updates stop. That is deliberate - an endpoint that
// cannot authenticate its caller should not be broadcasting to admins.

serve(async (req: Request) => {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const expected = Deno.env.get("DASHBOARD_UPDATE_SECRET");
  if (!expected) {
    console.error("DASHBOARD_UPDATE_SECRET is not configured; refusing.");
    return json({ error: "Not configured" }, 503);
  }

  const presented = req.headers.get("x-dashboard-secret") ?? "";
  if (!timingSafeEqual(presented, expected)) {
    return json({ error: "Forbidden" }, 403);
  }

  try {
    const body = await req.json().catch(() => null);
    const record = body?.record;
    if (record === undefined || record === null) {
      return json({ error: "record is required" }, 400);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false } },
    );

    const channel = supabase.channel("dashboard");
    await channel.send({
      type: "broadcast",
      event: "metrics-update",
      payload: { record },
    });
    await supabase.removeChannel(channel);

    return json({ message: "Metrics update broadcasted" }, 200);
  } catch (err) {
    console.error("dashboard-update failed:", err);
    return json({ error: "Unexpected error" }, 500);
  }
});

/**
 * Constant-time comparison. A plain `===` on a secret leaks its prefix length
 * through timing; with an endpoint this easy to hammer, that is worth avoiding.
 */
function timingSafeEqual(a: string, b: string): boolean {
  const ab = new TextEncoder().encode(a);
  const bb = new TextEncoder().encode(b);
  if (ab.length !== bb.length) return false;
  let diff = 0;
  for (let i = 0; i < ab.length; i++) diff |= ab[i] ^ bb[i];
  return diff === 0;
}

// No CORS headers: this endpoint is called server-to-server by a database
// trigger, never from a browser, so it should not advertise cross-origin
// access to anyone.
function json(payload: unknown, status: number): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
