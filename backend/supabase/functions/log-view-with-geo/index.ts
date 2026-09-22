import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeadersFor } from "../_shared/cors.ts";

// Records a product view with coarse geo data.
//
// This function never worked. It inserted `{ file_id, country }` into
// public.views, and `file_id` is not a column in that table - not in the real
// production schema (user_id, country, item_id, item_table, state, pincode,
// item_uid) and not in the one the migrations build either. Every insert
// failed with a 400. It also sent no CORS headers and handled no OPTIONS
// preflight, so a browser could not call it at all even once the insert was
// fixed.
//
// Rewritten against the real table, with the polymorphic keying the rest of
// the app uses: item_id (the integer id as text) + item_table.

const PRODUCT_TABLES = new Set([
  "products",
  "designerproducts",
  "manufacturerproducts",
]);

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

interface ViewBody {
  item_id: string | number;
  item_table: string;
  item_uid?: string | null;
}

serve(async (req: Request) => {
  const corsHeaders = corsHeadersFor(req);

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405, corsHeaders);
  }

  try {
    const body = (await req.json().catch(() => null)) as ViewBody | null;

    const itemId = body?.item_id === undefined || body?.item_id === null
      ? ""
      : String(body.item_id).trim();
    const itemTable = String(body?.item_table ?? "").trim();

    if (!itemId) {
      return json({ error: "item_id is required" }, 400, corsHeaders);
    }
    // Allowlisted rather than free text: item_table is written straight into a
    // column the analytics RPCs filter on, so a typo (or anything else) would
    // quietly produce rows nothing can ever read back.
    if (!PRODUCT_TABLES.has(itemTable)) {
      return json(
        { error: `item_table must be one of ${[...PRODUCT_TABLES].join(", ")}` },
        400,
        corsHeaders,
      );
    }

    const itemUid = typeof body?.item_uid === "string" && UUID_RE.test(body.item_uid)
      ? body.item_uid
      : null;

    // Attribute the view to the signed-in user when there is one. Views from
    // logged-out visitors are still recorded, with a null user_id.
    let userId: string | null = null;
    const authHeader = req.headers.get("Authorization") ?? "";
    if (authHeader) {
      const anonClient = createClient(
        Deno.env.get("SUPABASE_URL")!,
        Deno.env.get("SUPABASE_ANON_KEY")!,
        { global: { headers: { Authorization: authHeader } } },
      );
      const { data } = await anonClient.auth.getUser();
      userId = data?.user?.id ?? null;
    }

    const geo = await lookupGeo(req);

    // Service role: public.views has RLS enabled, and an anonymous visitor has
    // no policy permitting an insert.
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false } },
    );

    const { error } = await admin.from("views").insert({
      user_id: userId,
      item_id: itemId,
      item_table: itemTable,
      item_uid: itemUid,
      country: geo.country,
      state: geo.state,
      pincode: geo.pincode,
    });

    if (error) {
      console.error("views insert failed:", error.message);
      return json({ error: "Could not record view" }, 500, corsHeaders);
    }

    return json({ success: true }, 200, corsHeaders);
  } catch (err) {
    console.error("log-view-with-geo failed:", err);
    return json({ error: "Unexpected error" }, 500, corsHeaders);
  }
});

/**
 * Best-effort IP geolocation.
 *
 * ipapi.co's free tier is ~1000 lookups/day and this runs on every view, so
 * beyond that it returns errors and geo silently becomes 'Unknown'. The call
 * is capped at 1.5s and every failure degrades to nulls, because a view must
 * still be recorded when the lookup is rate-limited, slow, or down - the old
 * code would block on it indefinitely.
 */
async function lookupGeo(req: Request): Promise<{
  country: string | null;
  state: string | null;
  pincode: string | null;
}> {
  const none = { country: null, state: null, pincode: null };

  const ip = (req.headers.get("x-forwarded-for") ?? "").split(",")[0].trim();
  if (!ip) return none;

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 1500);
  try {
    const res = await fetch(`https://ipapi.co/${encodeURIComponent(ip)}/json/`, {
      signal: controller.signal,
    });
    if (!res.ok) return none;
    const g = await res.json();
    if (g?.error) return none;
    return {
      country: g.country_name ?? null,
      state: g.region ?? null,
      pincode: g.postal ?? null,
    };
  } catch {
    return none;
  } finally {
    clearTimeout(timer);
  }
}

function json(
  payload: unknown,
  status: number,
  cors: Record<string, string>,
): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}
