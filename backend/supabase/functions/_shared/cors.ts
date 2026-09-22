// CORS for the edge functions.
//
// This used to be a flat `Access-Control-Allow-Origin: *` on every function,
// including the authenticated ones (run-ai-fill, ai-credentials). A wildcard
// means any page on any origin can invoke them with a user's credentials if it
// can get hold of a JWT, and it also blocks ever using cookie auth here.
//
// Now the origin is echoed back only when it is on the allowlist. Unknown
// origins get no ACAO header at all, so the browser blocks the response.
//
// ALLOWED_ORIGINS (optional) overrides the defaults: a comma-separated list,
//   supabase secrets set ALLOWED_ORIGINS="https://www.dagina.design,https://dagina.design"
// Set it for any environment with extra preview/staging domains.

const DEFAULT_ORIGINS = [
  "https://www.dagina.design",
  "https://dagina.design",
];

// Local Flutter web dev servers (`flutter run -d chrome` picks a random port).
// Only pages served from the developer's own machine carry these origins, so
// any port is safe; the pattern is anchored so look-alike hosts such as
// "http://localhost.evil.com" do not match.
const LOCAL_DEV_ORIGIN = /^http:\/\/(localhost|127\.0\.0\.1)(:\d{1,5})?$/;

function allowedOrigins(): string[] {
  const configured = Deno.env.get("ALLOWED_ORIGINS");
  if (!configured) return DEFAULT_ORIGINS;
  return configured
    .split(",")
    .map((o) => o.trim())
    .filter((o) => o.length > 0);
}

const BASE_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
  "Access-Control-Max-Age": "86400",
  // Responses differ per Origin, so caches must not share them across origins.
  Vary: "Origin",
};

/**
 * CORS headers for a specific request. Pass the incoming Request so the
 * caller's Origin can be checked against the allowlist.
 */
export function corsHeadersFor(req: Request): Record<string, string> {
  const origin = req.headers.get("Origin") ?? "";
  const headers = { ...BASE_HEADERS };
  if (origin && (allowedOrigins().includes(origin) || LOCAL_DEV_ORIGIN.test(origin))) {
    headers["Access-Control-Allow-Origin"] = origin;
  }
  return headers;
}

/**
 * Static fallback for non-browser callers (cron, server-to-server), which do
 * not send an Origin and do not enforce CORS. Deliberately carries no
 * Access-Control-Allow-Origin: a browser request that lands here is not
 * granted cross-origin access by default.
 *
 * Prefer `corsHeadersFor(req)` in anything a browser calls.
 */
export const corsHeaders: Record<string, string> = { ...BASE_HEADERS };
