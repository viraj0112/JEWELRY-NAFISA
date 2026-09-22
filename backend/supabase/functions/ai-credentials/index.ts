import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeadersFor } from "../_shared/cors.ts";
import {
  decryptSecret,
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
//   set_my_llm_model   (self)  the caller's model preference
//   clear_my_llm_key   (self)
//   list_models        (self; scope "global" is admin) models a key can use
//
// Every action that stores a model name first checks it against the models
// the relevant key can actually call, so a typo like "gemini-2-flash" is
// rejected at save time instead of failing every fill later.

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

async function handle(req: Request): Promise<Response> {
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
      case "set_my_llm_model":
        return await setMyLlmModel(admin, callerId, body);
      case "clear_my_llm_key":
        return await clearMyLlmKey(admin, callerId);
      case "list_models":
        return await listModels(admin, callerId, body);
      default:
        return json({ error: `Unknown action '${action}'` }, 400);
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    // Never echo a stack or a value that might contain key material.
    const status = error instanceof HttpError ? error.status : 500;
    return json({ error: message }, status);
  }
}

// Every response leaves through here, so the allowlisted CORS headers are
// applied in exactly one place and json() below stays CORS-agnostic.
serve(async (req: Request) => {
  const cors = corsHeadersFor(req);
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }
  const res = await handle(req);
  for (const [k, v] of Object.entries(cors)) res.headers.set(k, v);
  return res;
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

  // Batch/rate knobs for large fills; bounds mirror the table CHECKs.
  const intSettings: [string, number, number][] = [
    ["fill_batch_size", 1, 100],
    ["fill_batch_pause_seconds", 0, 600],
    ["llm_requests_per_minute", 0, 10000],
  ];
  for (const [field, min, max] of intSettings) {
    if (body?.[field] === undefined || body?.[field] === null) continue;
    const value = Number(body[field]);
    if (!Number.isInteger(value) || value < min || value > max) {
      return json({ error: `${field} must be a whole number from ${min} to ${max}` }, 400);
    }
    payload[field] = value;
  }

  const model = typeof body?.default_model === "string"
    ? body.default_model.trim()
    : "";
  const newKey = typeof body?.llm_api_key === "string" ? body.llm_api_key.trim() : "";

  // Validate against the key that will be stored: the new one if supplied,
  // otherwise the global key already on file.
  if (model) {
    const checkKey = newKey || (await resolveStoredKey(admin, callerId, "global"))?.key;
    if (checkKey) await assertModelAvailable(checkKey, model);
    payload.default_model = model;
  } else if (newKey) {
    await fetchGenerateContentModels(newKey);
  }

  if (typeof body?.llm_api_key === "string") {
    const raw = newKey;
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

  // Checks the key itself as well: a key Google rejects never gets stored.
  if (model) {
    await assertModelAvailable(raw, model);
  } else {
    await fetchGenerateContentModels(raw);
  }

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

async function setMyLlmModel(
  admin: SupabaseClient,
  callerId: string,
  body: Record<string, unknown>,
): Promise<Response> {
  const model = typeof body?.llm_model === "string" ? body.llm_model.trim() : "";

  // Blank clears the preference (fills then use the admin default model).
  if (model) {
    const resolved = await resolveStoredKey(admin, callerId, "mine");
    if (!resolved) {
      return json({ error: "No LLM key available to check this model against" }, 400);
    }
    await assertModelAvailable(resolved.key, model);
  }

  const { error } = await admin
    .from("api_credentials")
    .update({ llm_model: model || null })
    .eq("user_id", callerId);
  if (error) return json({ error: error.message }, 500);
  return json({ ok: true }, 200);
}

// ---------------------------------------------------------------------------
// Model discovery
// ---------------------------------------------------------------------------

type KeySource = "provided" | "own" | "global";

/**
 * The key a fill would use, mirroring the backend's precedence: the caller's
 * own key, else the admin's global key. `scope: "global"` skips the caller's
 * own key (admin settings screen).
 */
async function resolveStoredKey(
  admin: SupabaseClient,
  callerId: string,
  scope: "mine" | "global",
): Promise<{ key: string; source: KeySource } | null> {
  if (scope === "mine") {
    const { data: cred } = await admin
      .from("api_credentials")
      .select("llm_api_key, llm_api_key_enc")
      .eq("user_id", callerId)
      .maybeSingle();
    const own = cred?.llm_api_key_enc
      ? await decryptSecret(cred.llm_api_key_enc)
      : (cred?.llm_api_key ?? "");
    if (own) return { key: own, source: "own" };
  }

  const { data: settings } = await admin
    .from("llm_settings")
    .select("global_llm_api_key, global_llm_api_key_enc")
    .eq("id", 1)
    .maybeSingle();
  const global = settings?.global_llm_api_key_enc
    ? await decryptSecret(settings.global_llm_api_key_enc)
    : (settings?.global_llm_api_key ?? "");
  return global ? { key: global, source: "global" } : null;
}

interface GeminiModel {
  id: string;           // e.g. "gemini-2.5-flash" - what gets stored/used
  display_name: string; // e.g. "Gemini 2.5 Flash"
}

// Model families that can't do the fill's job (read an image, answer in JSON):
// speech in/out, embeddings, image *generation*, realtime audio/video, agents
// and tool-calling specialisations.
const UNSUITABLE_MODEL_MARKERS = [
  "tts", "transcribe", "embedding", "image", "audio", "live", "computer-use",
  "robotics", "customtools",
];

/**
 * Every model this key can call `generateContent` on, straight from Google
 * AI Studio's model list. The key goes in a header, not the query string, so
 * it never shows up in request logs.
 */
async function fetchGenerateContentModels(apiKey: string): Promise<GeminiModel[]> {
  const models: GeminiModel[] = [];
  let pageToken = "";
  do {
    const url = new URL("https://generativelanguage.googleapis.com/v1beta/models");
    url.searchParams.set("pageSize", "1000");
    if (pageToken) url.searchParams.set("pageToken", pageToken);

    const resp = await fetch(url, { headers: { "x-goog-api-key": apiKey } });
    const data = await resp.json().catch(() => ({}));
    if (!resp.ok) {
      if (resp.status === 400 || resp.status === 401 || resp.status === 403) {
        throw new HttpError("Google rejected this API key. Check it in AI Studio.", 400);
      }
      throw new HttpError(`Could not reach Google AI Studio (HTTP ${resp.status})`, 502);
    }

    for (const m of data.models ?? []) {
      if (!(m.supportedGenerationMethods ?? []).includes("generateContent")) continue;
      const id = String(m.name ?? "").replace(/^models\//, "");
      if (id) models.push({ id, display_name: String(m.displayName ?? id) });
    }
    pageToken = data.nextPageToken ?? "";
  } while (pageToken);
  return models;
}

/** Throws a 400 naming some valid choices when `model` isn't callable. */
async function assertModelAvailable(apiKey: string, model: string) {
  // Model ids are short slugs; reject anything else before it is stored or
  // echoed back in an error message.
  if (!/^[a-zA-Z0-9._-]{1,100}$/.test(model)) {
    throw new HttpError("Invalid model name", 400);
  }
  const available = await fetchGenerateContentModels(apiKey);
  if (available.some((m) => m.id === model)) return;
  const suggestions = available
    .filter((m) => isSuitableModel(m.id))
    .sort(compareModels)
    .slice(0, 5)
    .map((m) => m.id)
    .join(", ");
  throw new HttpError(
    `Model "${model}" is not available for this API key.` +
      (suggestions ? ` Try one of: ${suggestions}` : ""),
    400,
  );
}

function isSuitableModel(id: string): boolean {
  return id.startsWith("gemini") &&
    !UNSUITABLE_MODEL_MARKERS.some((marker) => id.includes(marker));
}

async function listModels(
  admin: SupabaseClient,
  callerId: string,
  body: Record<string, unknown>,
): Promise<Response> {
  const scope = body?.scope === "global" ? "global" : "mine";
  if (scope === "global") await requireAdmin(admin, callerId);

  // A key the user has just typed (not saved yet) takes priority, so the
  // picker can show that key's models before anything is stored.
  const typed = typeof body?.llm_api_key === "string" ? body.llm_api_key.trim() : "";
  const resolved = typed
    ? { key: typed, source: "provided" as KeySource }
    : await resolveStoredKey(admin, callerId, scope);
  if (!resolved) {
    return json({ error: "No LLM API key saved yet. Add a key to see its models." }, 400);
  }

  const models = (await fetchGenerateContentModels(resolved.key))
    .filter((m) => isSuitableModel(m.id))
    .sort(compareModels);

  return json({ key_source: resolved.source, models }, 200);
}

/**
 * Picker order: rolling "-latest" aliases first, then newest version first,
 * and within a version stable before preview/experimental, then by name.
 */
function compareModels(a: GeminiModel, b: GeminiModel): number {
  const rank = (id: string) => ({
    alias: id.endsWith("-latest") ? 0 : 1,
    version: Number(id.match(/^gemini-(\d+(?:\.\d+)?)/)?.[1] ?? 0),
    unstable: /preview|exp/.test(id) ? 1 : 0,
  });
  const ra = rank(a.id), rb = rank(b.id);
  return ra.alias - rb.alias ||
    rb.version - ra.version ||
    ra.unstable - rb.unstable ||
    a.id.localeCompare(b.id);
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
    headers: { "Content-Type": "application/json" },
  });
}
