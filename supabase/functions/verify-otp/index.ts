// Supabase Edge Function: verify-otp
// Calls MSG91 REST API to verify the OTP entered by the user.
//
// ─── MSG91 CREDENTIALS SETUP ─────────────────────────────────────────────────
// Same credentials as send-otp function.
// Run: supabase secrets set MSG91_AUTH_KEY=<your_auth_key>
//
// Deploy:
//   supabase functions deploy verify-otp
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
    // ── 1. Read credentials ────────────────────────────────────────────────
    // TODO: Must be set via: supabase secrets set MSG91_AUTH_KEY=xxx
    const authKey = Deno.env.get("MSG91_AUTH_KEY");

    if (!authKey) {
      return new Response(
        JSON.stringify({
          success: false,
          message: "OTP service is not configured. Please contact support.",
        }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ── 2. Parse request body ──────────────────────────────────────────────
    const { phone, otp } = await req.json();
    if (!phone || !otp) {
      return new Response(
        JSON.stringify({ success: false, message: "Phone and OTP are required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const mobile = String(phone).replace(/^\+/, "").replace(/\s+/g, "");
    const otpValue = String(otp).trim();

    // ── 3. Call MSG91 Verify OTP API ──────────────────────────────────────
    // Docs: https://docs.msg91.com/reference/verify-otp
    const msg91Url = `https://control.msg91.com/api/v5/otp/verify?authkey=${authKey}&mobile=${mobile}&otp=${otpValue}`;

    const msg91Response = await fetch(msg91Url, {
      method: "GET",
      headers: { "Content-Type": "application/json" },
    });

    const msg91Data = await msg91Response.json();
    console.log("[verify-otp] MSG91 response:", JSON.stringify(msg91Data));

    if (msg91Data.type === "success") {
      return new Response(
        JSON.stringify({ success: true, message: "OTP verified successfully" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    } else {
      // MSG91 error messages: "OTP not match", "OTP expired", etc.
      const message = msg91Data.message ?? "OTP verification failed";
      return new Response(
        JSON.stringify({ success: false, message }),
        { status: 422, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
  } catch (error) {
    console.error("[verify-otp] Unexpected error:", error);
    return new Response(
      JSON.stringify({ success: false, message: "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
