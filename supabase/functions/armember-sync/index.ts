import { serve } from "https://deno.land/std@0.203.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

const ARMEMBER_WEBHOOK_SECRET = Deno.env.get("ARMEMBER_SECURITY_KEY");

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const providedSecret = req.headers.get("x-armember-secret");
  if (!providedSecret || providedSecret !== ARMEMBER_WEBHOOK_SECRET) {
    console.error("Unauthorized: Missing or invalid secret key.");
    return new Response(JSON.stringify({ error: "Unauthorized: Invalid secret key" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false } }
    );
    const payload = await req.json();
    console.log("Received webhook payload:", payload);

    const { user_email, plan_name, status } = payload;
    if (!user_email || !plan_name || !status) {
      return new Response(JSON.stringify({ error: "Payload missing required fields" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const isMember = status === 'active';

    const { data, error } = await supabase
      .from("users")
      .update({
        is_member: isMember,
        membership_plan: plan_name,
        membership_status: status,
      })
      .eq("email", user_email)
      .select()
      .single();

    if (error) {
      console.error("Supabase query error:", error);
      if (error.code === 'PGRST116') {
        return new Response(JSON.stringify({ error: `User not found.` }), {
          status: 404, 
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
      throw error;
    }

    return new Response(JSON.stringify({ success: true, updatedUser: data }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });

  } catch (error) {
    if (error instanceof Error) {
      console.error("Caught unhandled error:", error.message);
      return new Response(JSON.stringify({ error: error.message }), {
        status: 400, 
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ error: "An unexpected error occurred." }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});