import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import {
  encryptSecret,
  generateMasterKey,
  keyHint,
  sha256Hex,
} from "../_shared/crypto.ts";

// Single write path for every AI-fill credential.
//
// The browser is no longer allowed to write `x_api_key` or `llm_api_key`
// directly (the migration revoked the column privileges), because a secret
// written from the client is a secret the client has held in memory and could
// have leaked. Everything goes through here, where the plaintext is encrypted
// before it touches Postgres and — for master keys — returned to the caller
// exactly once and never again.
//
// Actions:
//   issue_key          (admin) generate/rotate a user's dgn_ master key + TTL
//   set_active         (admin) enable/disable a key
//   revoke_key         (admin) delete the key material outright
//   set_global_llm_key (admin) platform-wide fallback LLM key
//   set_my_llm_key     (self)  the caller's own provider key
//   clear_my_llm_key   (self)

type Ttl = "week" | "month" | "year" | "never";

const TTL_DAYS: Record<Exclude<Ttl, "never">, number> = {
  week: 7,
  month: 30,
  year: 365,
};

function expiryFor(ttl: Ttl): string | null {
  if (ttl === "never") return null;
  const days = TTL_DAYS[ttl];
  return new Date(Date.now() + days * 86_400_000).toISOString();
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 1. Who is calling? Built from the caller's own JWT, so `getUser()`
    //    verifies the signature — a client cannot claim to be someone else.
    const authHeader = req.headers.get("Authorization") ?? "";
    const anonClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: userData, error: userErr } = await anonClient.auth.getUser();
    if (userErr || !userData?.user) return json({ error: "Not authenticated" }, 401);
    const callerId = userData.user.id;

    // 2. Service-role client: bypasses RLS *and* the column GRANTs, which is
    //    precisely why this logic lives server-side and not in the app.
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false } },
    );

    const body = await req.json().catch(() => ({}));
    const action = String(body?.action ?? "");

    switch (action) {
      case "issue_key":
        return await issueKey(admin, callerId, body);
      case "set_active":
        return await setActive(admin, callerId, body);
      case "revoke_key":
        return await revokeKey(admin, callerId, body);
      case "set_global_llm_key":
        return await setGlobalLlmKey(admin, callerId, body);
      case "set_my_llm_key":
        return await setMyLlmKey(admin, callerId, body);
      case "clear_my_llm_key":
        return await clearMyLlmKey(admin, callerId);
      default:
        return json({ error: `Unknown action '${action}'` }, 400);
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    // Never echo a stack or a value that might contain key material.
    const status = error instanceof HttpError ? error.status : 500;
    return json({ error: message }, status);
  }
});

// ---------------------------------------------------------------------------
// Admin actions
// ---------------------------------------------------------------------------

async function requireAdmin(admin: SupabaseClient, callerId: string) {
  const { data } = await admin
    .from("users")
    .select("role")
    .eq("id", callerId)
    .maybeSingle();
  if ((data?.role ?? "member") !== "admin") {
    throw new HttpError("Admin role required", 403);
  }
}

async function issueKey(
  admin: SupabaseClient,
  callerId: string,
  body: Record<string, unknown>,
): Promise<Response> {
  await requireAdmin(admin, callerId);

  const userId = String(body?.user_id ?? "");
  if (!userId) return json({ error: "user_id is required" }, 400);

  const ttl = (String(body?.ttl ?? "never") as Ttl);
  if (!["week", "month", "year", "never"].includes(ttl)) {
    return json({ error: "ttl must be week | month | year | never" }, 400);
  }

  const { data: target } = await admin
    .from("users")
    .select("id")
    .eq("id", userId)
    .maybeSingle();
  if (!target) return json({ error: "No such user" }, 404);

  const apiKey = generateMasterKey();            // dgn_<32 hex>
  const expiresAt = expiryFor(ttl);

  // Hash for lookup, ciphertext for replay. Storing both is deliberate:
  //  - the hash lets the FastAPI backend verify an incoming header without
  //    the plaintext existing anywhere in the DB;
  //  - the ciphertext lets `run-ai-fill` replay the key to that backend on the
  //    user's behalf, so the browser never receives it.
  const { error } = await admin.from("api_credentials").upsert({
    user_id: userId,
    x_api_key: null,                             // clear any legacy plaintext
    x_api_key_hash: await sha256Hex(apiKey),
    x_api_key_enc: await encryptSecret(apiKey),
    key_prefix: apiKey.slice(0, 12),             // 'dgn_4452abeb'
    expires_at: expiresAt,
    is_active: true,
  }, { onConflict: "user_id" });

  if (error) return json({ error: `Could not issue key: ${error.message}` }, 500);

  // The ONLY time the plaintext leaves this function. The admin must copy it
  // now; there is no way to read it back afterwards.
  return json({
    api_key: apiKey,
    key_prefix: apiKey.slice(0, 12),
    expires_at: expiresAt,
    ttl,
  }, 200);
}

async function setActive(
  admin: SupabaseClient,
  callerId: string,
  body: Record<string, unknown>,
): Promise<Response> {
  await requireAdmin(admin, callerId);
  const userId = String(body?.user_id ?? "");
  if (!userId) return json({ error: "user_id is required" }, 400);
  const isActive = body?.is_active === true;

  const { error } = await admin
    .from("api_credentials")
    .update({ is_active: isActive })
    .eq("user_id", userId);
  if (error) return json({ error: error.message }, 500);
  return json({ ok: true, is_active: isActive }, 200);
}

async function revokeKey(
  admin: SupabaseClient,
  callerId: string,
  body: Record<string, unknown>,
): Promise<Response> {
  await requireAdmin(admin, callerId);
  const userId = String(body?.user_id ?? "");
  if (!userId) return json({ error: "user_id is required" }, 400);

  const { error } = await admin.from("api_credentials").update({
    x_api_key: null,
    x_api_key_hash: null,
    x_api_key_enc: null,
    key_prefix: null,
    expires_at: null,
    is_active: false,
  }).eq("user_id", userId);
  if (error) return json({ error: error.message }, 500);
  return json({ ok: true }, 200);
}

async function setGlobalLlmKey(
  admin: SupabaseClient,
  callerId: string,
  body: Record<string, unknown>,
): Promise<Response> {
  await requireAdmin(admin, callerId);

  const payload: Record<string, unknown> = { id: 1, updated_by: callerId };

  const model = typeof body?.default_model === "string"
    ? body.default_model.trim()
    : "";
  if (model) payload.default_model = model;

  if (typeof body?.llm_api_key === "string") {
    const raw = body.llm_api_key.trim();
    if (raw) {
      payload.global_llm_api_key_enc = await encryptSecret(raw);
      payload.global_llm_key_hint = keyHint(raw);
    } else {
      payload.global_llm_api_key_enc = null;
      payload.global_llm_key_hint = null;
    }
    payload.global_llm_api_key = null;  // retire the plaintext column
  }

  const { error } = await admin.from("llm_settings").upsert(payload);
  if (error) return json({ error: error.message }, 500);
  return json({ ok: true }, 200);
}

// ---------------------------------------------------------------------------
// Self-service actions (any authenticated user, own row only)
// ---------------------------------------------------------------------------

async function setMyLlmKey(
  admin: SupabaseClient,
  callerId: string,
  body: Record<string, unknown>,
): Promise<Response> {
  const raw = typeof body?.llm_api_key === "string" ? body.llm_api_key.trim() : "";
  if (!raw) return json({ error: "llm_api_key is required" }, 400);

  const model = typeof body?.llm_model === "string" ? body.llm_model.trim() : "";

  // `user_id` is taken from the verified JWT, never from the request body —
  // otherwise any user could overwrite another user's key.
  const { error } = await admin.from("api_credentials").upsert({
    user_id: callerId,
    llm_api_key: null,                    // retire the plaintext column
    llm_api_key_enc: await encryptSecret(raw),
    llm_key_hint: keyHint(raw),
    ...(model ? { llm_model: model } : {}),
  }, { onConflict: "user_id" });

  if (error) return json({ error: error.message }, 500);
  return json({ ok: true, llm_key_hint: keyHint(raw) }, 200);
}

async function clearMyLlmKey(
  admin: SupabaseClient,
  callerId: string,
): Promise<Response> {
  const { error } = await admin.from("api_credentials").update({
    llm_api_key: null,
    llm_api_key_enc: null,
    llm_key_hint: null,
  }).eq("user_id", callerId);
  if (error) return json({ error: error.message }, 500);
  return json({ ok: true }, 200);
}

// ---------------------------------------------------------------------------

class HttpError extends Error {
  constructor(message: string, readonly status: number) {
    super(message);
  }
}

function json(payload: unknown, status: number): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
