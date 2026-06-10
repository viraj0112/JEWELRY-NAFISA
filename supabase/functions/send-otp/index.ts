// Supabase Edge Function: send-otp
// Calls MSG91 REST API to send an OTP to the provided phone number.
//
// ─── MSG91 CREDENTIALS SETUP ─────────────────────────────────────────────────
// Run these commands once to securely store your credentials:
//
//   supabase secrets set MSG91_AUTH_KEY=<your_auth_key>
//   supabase secrets set MSG91_SENDER_ID=DAGINA
//   supabase secrets set MSG91_TEMPLATE_ID=<your_otp_template_id>
//
// Where to find them:
//   Auth Key    → https://msg91.com → API Keys → Generate Key
//   Sender ID   → https://msg91.com → SMS → Sender IDs (e.g. "DAGINA")
//   Template ID → https://msg91.com → SMS → Templates → your OTP template → copy ID
//
// Deploy this function:
//   supabase functions deploy send-otp
// ─────────────────────────────────────────────────────────────────────────────

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // ── 1. Read credentials from Supabase secrets ──────────────────────────
    // TODO: Set these via: supabase secrets set MSG91_AUTH_KEY=xxx
    const authKey = Deno.env.get("MSG91_AUTH_KEY");
    const senderId = Deno.env.get("MSG91_SENDER_ID") ?? "DAGINA";
    const templateId = Deno.env.get("MSG91_TEMPLATE_ID");

    if (!authKey || !templateId) {
      console.error("[send-otp] MSG91 credentials not configured.");
      return new Response(
        JSON.stringify({
          success: false,
          message: "OTP service is not configured. Please contact support.",
        }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ── 2. Parse request body ──────────────────────────────────────────────
    const { phone } = await req.json();
    if (!phone || typeof phone !== "string") {
      return new Response(
        JSON.stringify({ success: false, message: "Invalid phone number" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // MSG91 expects mobile without '+', e.g. "919876543210"
    const mobile = phone.replace(/^\+/, "").replace(/\s+/g, "");

    // ── 3. Call MSG91 Send OTP API ─────────────────────────────────────────
    // Docs: https://docs.msg91.com/reference/send-otp
    const msg91Url = `https://control.msg91.com/api/v5/otp?template_id=${templateId}&mobile=${mobile}&authkey=${authKey}&sender=${senderId}`;

    const msg91Response = await fetch(msg91Url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ mobile }),
    });

    const msg91Data = await msg91Response.json();
    console.log("[send-otp] MSG91 response:", JSON.stringify(msg91Data));

    if (msg91Data.type === "success") {
      return new Response(
        JSON.stringify({ success: true, message: "OTP sent successfully" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    } else {
      return new Response(
        JSON.stringify({
          success: false,
          message: msg91Data.message ?? "Failed to send OTP",
        }),
        { status: 422, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
  } catch (error) {
    console.error("[send-otp] Unexpected error:", error);
    return new Response(
      JSON.stringify({ success: false, message: "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
