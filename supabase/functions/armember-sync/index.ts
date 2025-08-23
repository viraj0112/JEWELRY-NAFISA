import { serve } from "https://deno.land/std@0.203.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!supabaseUrl || !supabaseServiceRoleKey) {
  throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY environment variables.");
}

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method Not Allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const supabase = createClient(
      supabaseUrl,
      supabaseServiceRoleKey,
      { auth: { persistSession: false } }
    );
    const payload = await req.json();
    console.log("Received webhook payload:", payload);

    const { user_email, plan_name, status } = payload;
    if (!user_email || !plan_name || !status) {
      return new Response(JSON.stringify({ error: "Payload missing required fields: user_email, plan_name, status" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const isMember = status === 'active';
    const { data, error } = await supabase
      .from("users")
      .update({
        is_member: isMember,
        membership_plan: plan_name,
      })
      .eq("email", user_email)
      .select() // Select the updated row to return it in the response
      .single(); // Use .single() to ensure exactly one row is updated
    if (error) {
      console.error("Supabase query error:", error);
      if (error.code === 'PGRST116') {
        return new Response(JSON.stringify({ error: `User with email ${user_email} not found.` }), {
          status: 404, // Not Found
          headers: { "Content-Type": "application/json" },
        });
      }
      throw error;
    }
    return new Response(JSON.stringify({ success: true, updatedUser: data }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    });

  } catch (error) {
    console.error("Caught unhandled error:", error);
    let errorMessage = "An unexpected error occurred.";
    if (error instanceof Error) {
      errorMessage = error.message;
    }

    return new Response(JSON.stringify({ error: errorMessage }), {
      status: 400, // Bad Request
      headers: { "Content-Type": "application/json" },
    });
  }
});