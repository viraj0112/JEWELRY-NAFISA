import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import { decryptSecret } from "../_shared/crypto.ts";

// Server-side proxy for AI database prefill.
//
// The browser used to fetch each user's x-api-key and send it directly to the
// FastAPI backend, which meant the key was visible in the Network tab and
// browser console. This function keeps the key server-side: the browser sends
// only its Supabase session (the JWT it already holds for every request), and
// this function resolves the caller, looks up their key with the service role,
// and calls the backend. The key never reaches the browser.

interface FillBody {
  mode: "admin" | "mine";
  table_name?: string; // admin only
  limit: number;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 1. Identify the caller from their JWT. Creating the client with the
    // caller's Authorization header means getUser() validates the signed token
    // and returns the real user - it cannot be spoofed from the browser.
    const authHeader = req.headers.get("Authorization") ?? "";
    const anonClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: userData, error: userErr } = await anonClient.auth.getUser();
    if (userErr || !userData?.user) {
      return json({ error: "Not authenticated" }, 401);
    }
    const userId = userData.user.id;

    const body = (await req.json()) as FillBody;
    const limit = Number(body?.limit ?? 0);
    if (!Number.isFinite(limit) || limit <= 0) {
      return json({ error: "limit must be a positive number" }, 400);
    }

    // 2. Service-role client for the credential/role lookups (bypasses RLS).
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false } },
    );

    const { data: cred, error: credErr } = await admin
      .from("api_credentials")
      .select("x_api_key, x_api_key_enc, is_active, expires_at")
      .eq("user_id", userId)
      .maybeSingle();

    if (credErr) return json({ error: "Credential lookup failed" }, 500);
    if (!cred) return json({ error: "No API key issued for this user" }, 403);
    if (cred.is_active === false) return json({ error: "API key is disabled" }, 403);

    // TTL. `expires_at` NULL means "never expires"; anything in the past is a
    // hard stop here as well as in the backend, so an expired key cannot be
    // used even if the backend check were ever bypassed.
    if (cred.expires_at && new Date(cred.expires_at).getTime() <= Date.now()) {
      return json({
        error: "Your API key expired. Ask your admin to generate a new one.",
      }, 403);
    }

    // New keys are stored encrypted; `x_api_key` is only populated for keys
    // issued before the encryption migration and is cleared on next rotation.
    let apiKey: string;
    try {
      apiKey = cred.x_api_key_enc
        ? await decryptSecret(cred.x_api_key_enc)
        : (cred.x_api_key ?? "");
    } catch (_e) {
      return json({ error: "Stored API key could not be read" }, 500);
    }
    if (!apiKey) return json({ error: "No API key issued for this user" }, 403);

    // 3. For an admin fill, confirm the caller is actually an admin server-side
    // rather than trusting a client-supplied flag.
    let mode = body?.mode === "admin" ? "admin" : "mine";
    if (mode === "admin") {
      const { data: urow } = await admin
        .from("users")
        .select("role")
        .eq("id", userId)
        .maybeSingle();
      if ((urow?.role ?? "member") !== "admin") {
        return json({ error: "Admin role required for a full-table fill" }, 403);
      }
    }

    // 4. Call the FastAPI backend with the key server-side. AI_FILL_BASE_URL
    // must be reachable from Supabase's servers and must be https in production
    // (the key rides in this header - plaintext http would expose it on the
    // wire, which is the leak this whole change exists to close).
    const baseUrl = Deno.env.get("AI_FILL_BASE_URL");
    if (!baseUrl) return json({ error: "AI_FILL_BASE_URL not configured" }, 500);
    if (!/^https:\/\//i.test(baseUrl)) {
      return json({ error: "AI_FILL_BASE_URL must use https" }, 500);
    }

    const path = mode === "admin"
      ? "/api/v1/process-database-fill"
      : "/api/v1/fill-my-products";
    const backendBody = mode === "admin"
      ? { table_name: body.table_name ?? "", limit }
      : { table_name: "ignored", limit };

    const resp = await fetch(`${baseUrl}${path}`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": apiKey,
      },
      body: JSON.stringify(backendBody),
    });

    // Pass the backend's response straight through. On error, forward the
    // backend's detail but never anything containing the key.
    const text = await resp.text();

    // 5. Record this invocation in the authoritative usage log. This is the
    // server choke point every fill passes through, so logging here captures
    // every user (admins included) and can't be skipped by the client. Parse
    // the backend's BatchFillResponse for the row counts when present. Wrapped
    // so a logging failure never affects the fill response the user gets.
    try {
      let total = 0, success = 0, failed = 0;
      if (resp.ok) {
        const parsed = JSON.parse(text) as {
          data?: { total?: number; success?: number; failed?: number };
        };
        total = Number(parsed?.data?.total ?? 0);
        success = Number(parsed?.data?.success ?? 0);
        failed = Number(parsed?.data?.failed ?? 0);
      }
      await admin.from("ai_fill_usage").insert({
        user_id: userId,
        mode,
        table_name: mode === "admin" ? (body.table_name ?? null) : null,
        requested_limit: limit,
        total_processed: total,
        success_count: success,
        failed_count: failed,
        http_status: resp.status,
        ok: resp.ok,
      });
      await admin
        .from("api_credentials")
        .update({ last_used_at: new Date().toISOString() })
        .eq("user_id", userId);
    } catch (logErr) {
      console.error("ai_fill_usage log failed:", logErr);
    }

    return new Response(text, {
      status: resp.status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    return json({ error: message }, 500);
  }
});

function json(payload: unknown, status: number): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
