import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeadersFor } from "../_shared/cors.ts";
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
  // Rows already attempted earlier in the same multi-batch run.
  exclude_ids?: number[];
}

// Matches the backend's request cap.
const MAX_EXCLUDE_IDS = 5000;

const PRODUCT_TABLES = ["products", "designerproducts", "manufacturerproducts"];
const OWN_TABLE_BY_ROLE: Record<string, string> = {
  designer: "designerproducts",
  manufacturer: "manufacturerproducts",
};

interface FillDetail {
  id?: number;
  status?: string;
  columns?: string[];
}

/**
 * Marks the rows the backend just filled as AI-filled (ai_filled_at plus the
 * accumulated ai_filled_columns), which is what keeps the catalog's "AI
 * Filled" badge after a reload. Done here because every app fill passes
 * through this function; the backend stamps too when it is new enough, and
 * writing the same stamp twice is harmless. `ownerId` scopes the update to
 * the caller's own rows for B2B fills. Failures are logged, never fatal.
 */
async function stampAiFilled(
  // deno-lint-ignore no-explicit-any
  admin: any,
  table: string,
  details: FillDetail[],
  ownerId: string | null,
): Promise<void> {
  const filled = details.filter(
    (d) => d.status === "filled" && Number.isSafeInteger(d.id),
  );
  if (filled.length === 0) return;

  let existingQuery = admin
    .from(table)
    .select("id, ai_filled_columns")
    .in("id", filled.map((d) => d.id));
  if (ownerId) existingQuery = existingQuery.eq("user_id", ownerId);
  const { data: existing, error: readErr } = await existingQuery;
  if (readErr) {
    console.error("ai_filled stamp read failed:", readErr.message);
    return;
  }

  const previous = new Map<number, string[]>(
    (existing ?? []).map((r: { id: number; ai_filled_columns: string[] | null }) =>
      [r.id, r.ai_filled_columns ?? []]
    ),
  );
  const now = new Date().toISOString();
  const results = await Promise.all(
    filled
      .filter((d) => previous.has(d.id!)) // only rows that exist (and are the owner's)
      .map((d) => {
        const columns = [
          ...new Set([...(previous.get(d.id!) ?? []), ...(d.columns ?? [])]),
        ].sort();
        let update = admin
          .from(table)
          .update({ ai_filled_at: now, ai_filled_columns: columns })
          .eq("id", d.id);
        if (ownerId) update = update.eq("user_id", ownerId);
        return update;
      }),
  );
  for (const { error } of results) {
    if (error) console.error("ai_filled stamp failed:", error.message);
  }
}

interface TokenUsage {
  input_tokens?: number;   // includes cached_tokens
  cached_tokens?: number;
  output_tokens?: number;
  thinking_tokens?: number;
}

interface ModelPrice {
  input_usd_per_million: number;
  output_usd_per_million: number;
  cached_input_usd_per_million: number | null;
}

/**
 * USD cost of one run. Thinking tokens are billed at the output rate; cached
 * input at the cached rate when the admin set one, else at the input rate.
 */
function costOf(usage: TokenUsage, price: ModelPrice): number {
  const input = Number(usage.input_tokens ?? 0);
  const cached = Math.min(Number(usage.cached_tokens ?? 0), input);
  const output = Number(usage.output_tokens ?? 0) + Number(usage.thinking_tokens ?? 0);
  const cachedRate = price.cached_input_usd_per_million ?? price.input_usd_per_million;
  const usd = ((input - cached) * Number(price.input_usd_per_million) +
    cached * Number(cachedRate) +
    output * Number(price.output_usd_per_million)) / 1_000_000;
  return Math.round(usd * 1_000_000) / 1_000_000;
}

async function handle(req: Request): Promise<Response> {
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
    const rawExclude = body?.exclude_ids ?? [];
    if (
      !Array.isArray(rawExclude) || rawExclude.length > MAX_EXCLUDE_IDS ||
      !rawExclude.every((id) => Number.isSafeInteger(id))
    ) {
      return json({ error: `exclude_ids must be up to ${MAX_EXCLUDE_IDS} integer ids` }, 400);
    }
    const excludeIds = rawExclude as number[];

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
    const mode = body?.mode === "admin" ? "admin" : "mine";
    const { data: urow } = await admin
      .from("users")
      .select("role")
      .eq("id", userId)
      .maybeSingle();
    const role = urow?.role ?? "member";
    if (mode === "admin" && role !== "admin") {
      return json({ error: "Admin role required for a full-table fill" }, 403);
    }
    // The table this fill writes to - same rule the backend applies (admin:
    // the requested table; B2B: derived from the verified role, never the body).
    const productTable = mode === "admin"
      ? (PRODUCT_TABLES.includes(body.table_name ?? "") ? body.table_name! : null)
      : (OWN_TABLE_BY_ROLE[role] ?? null);

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
      ? { table_name: body.table_name ?? "", limit, exclude_ids: excludeIds }
      : { table_name: "ignored", limit, exclude_ids: excludeIds };

    const resp = await fetch(`${baseUrl}${path}`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": apiKey,
      },
      body: JSON.stringify(backendBody),
    });

    // Pass the backend's response through (with cost added on success). On
    // error, forward the backend's detail but never anything containing the key.
    let text = await resp.text();

    // 5. Record this invocation in the authoritative usage log. This is the
    // server choke point every fill passes through, so logging here captures
    // every user (admins included) and can't be skipped by the client. Parse
    // the backend's BatchFillResponse for the row counts when present. Wrapped
    // so a logging failure never affects the fill response the user gets.
    try {
      let total = 0, success = 0, failed = 0;
      let model: string | null = null;
      let usage: TokenUsage = {};
      let costUsd: number | null = null;
      if (resp.ok) {
        const parsed = JSON.parse(text) as {
          data?: {
            total?: number; success?: number; failed?: number;
            model?: string; usage?: TokenUsage;
            cost_usd?: number | null; price_configured?: boolean;
          };
        };
        total = Number(parsed?.data?.total ?? 0);
        success = Number(parsed?.data?.success ?? 0);
        failed = Number(parsed?.data?.failed ?? 0);
        model = parsed?.data?.model ?? null;
        usage = parsed?.data?.usage ?? {};

        // Price the run from the admin's table. Unknown model = cost unknown
        // (NULL), which the UI shows as "price not set" rather than $0.
        const { data: price } = model
          ? await admin
            .from("llm_model_pricing")
            .select("input_usd_per_million, output_usd_per_million, cached_input_usd_per_million")
            .eq("model", model)
            .maybeSingle()
          : { data: null };
        if (price) costUsd = costOf(usage, price as ModelPrice);

        if (parsed?.data) {
          parsed.data.cost_usd = costUsd;
          parsed.data.price_configured = price != null;
          text = JSON.stringify(parsed);
        }

        if (productTable) {
          const details = (parsed?.data as { details?: FillDetail[] } | undefined)
            ?.details ?? [];
          await stampAiFilled(
            admin,
            productTable,
            details,
            mode === "mine" ? userId : null,
          );
        }
      }
      const { error: logInsertErr } = await admin.from("ai_fill_usage").insert({
        user_id: userId,
        mode,
        table_name: mode === "admin" ? (body.table_name ?? null) : null,
        requested_limit: limit,
        total_processed: total,
        success_count: success,
        failed_count: failed,
        http_status: resp.status,
        ok: resp.ok,
        model,
        input_tokens: Number(usage.input_tokens ?? 0),
        cached_tokens: Number(usage.cached_tokens ?? 0),
        output_tokens: Number(usage.output_tokens ?? 0),
        thinking_tokens: Number(usage.thinking_tokens ?? 0),
        cost_usd: costUsd,
      });
      // supabase-js reports insert failures in the result, it doesn't throw.
      if (logInsertErr) console.error("ai_fill_usage insert failed:", logInsertErr.message);
      await admin
        .from("api_credentials")
        .update({ last_used_at: new Date().toISOString() })
        .eq("user_id", userId);
    } catch (logErr) {
      console.error("ai_fill_usage log failed:", logErr);
    }

    return new Response(text, {
      status: resp.status,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    return json({ error: message }, 500);
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

function json(payload: unknown, status: number): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
