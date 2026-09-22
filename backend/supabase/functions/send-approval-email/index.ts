import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeadersFor } from "../_shared/cors.ts";

// Sends an approval email via Resend.
//
// SECURITY: this endpoint previously took `{to, subject, html}` from any
// caller with no authentication whatsoever — an open relay that would send
// attacker-authored HTML from our own domain. Edge functions are public URLs,
// so "nobody knows about it" was never a control.
//
// It now mirrors run-ai-fill: the caller must present a valid Supabase session
// (the JWT the browser already holds), and that session must belong to a user
// whose `users.role` is `admin`, resolved server-side with the service role so
// a client-supplied flag can't stand in for it.
//
// The sender address comes from RESEND_FROM_EMAIL. It used to be the literal
// placeholder "youremail@example.com", which Resend rejects — so this function
// almost certainly never delivered a message.
//
//   supabase secrets set RESEND_API_KEY=...
//   supabase secrets set RESEND_FROM_EMAIL="Dagina Designs <noreply@dagina.design>"

interface ApprovalEmailBody {
  to: string;
  subject: string;
  html: string;
}

async function handle(req: Request): Promise<Response> {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    // 1. Identify the caller. Building the client with their Authorization
    // header means getUser() validates the signed token — it cannot be forged.
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader) return json({ error: "Not authenticated" }, 401);

    const anonClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: userData, error: userErr } = await anonClient.auth.getUser();
    if (userErr || !userData?.user) {
      return json({ error: "Not authenticated" }, 401);
    }

    // 2. Only admins may send. Resolved with the service role so RLS on
    // `users` cannot hide the row and turn a denial into an accidental allow.
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false } },
    );

    const { data: urow, error: roleErr } = await admin
      .from("users")
      .select("role")
      .eq("id", userData.user.id)
      .maybeSingle();

    if (roleErr) return json({ error: "Role lookup failed" }, 500);
    if ((urow?.role ?? "member") !== "admin") {
      return json({ error: "Admin role required" }, 403);
    }

    // 3. Validate the payload. `html` is admin-authored and goes out as-is;
    // `to` is checked so this can't be turned into a bulk sender by passing an
    // array or a comma-separated list.
    const body = (await req.json()) as ApprovalEmailBody;
    const to = typeof body?.to === "string" ? body.to.trim() : "";
    const subject = typeof body?.subject === "string" ? body.subject : "";
    const html = typeof body?.html === "string" ? body.html : "";

    if (!/^[^\s@,]+@[^\s@,]+\.[^\s@,]+$/.test(to)) {
      return json({ error: "A single valid recipient address is required" }, 400);
    }
    if (!subject || !html) {
      return json({ error: "subject and html are required" }, 400);
    }

    const resendApiKey = Deno.env.get("RESEND_API_KEY");
    const from = Deno.env.get("RESEND_FROM_EMAIL");
    if (!resendApiKey) return json({ error: "RESEND_API_KEY not configured" }, 500);
    if (!from) return json({ error: "RESEND_FROM_EMAIL not configured" }, 500);

    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${resendApiKey}`,
      },
      body: JSON.stringify({ from, to, subject, html }),
    });

    if (!res.ok) {
      // Log the provider's reason server-side; return something generic so a
      // caller can't probe our Resend configuration through error text.
      console.error("Resend rejected the message:", await res.text());
      return json({ error: "Failed to send email" }, 502);
    }

    return json({ success: true }, 200);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    console.error("send-approval-email failed:", message);
    return json({ error: "Unexpected error" }, 500);
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
