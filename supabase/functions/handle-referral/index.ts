import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { referral_code, new_user_id } = await req.json();
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const { data: referrer, error: referrerError } = await supabase
      .from("users")
      .select("id, is_member")
      .eq("referral_code", referral_code)
      .single();

    if (referrerError) throw new Error("Invalid referral code.");

    const creditsForReferrer = referrer.is_member ? 3 : 2;

    await supabase.rpc("increment_user_credits", {
      user_id_to_update: referrer.id,
      credits_to_add: creditsForReferrer,
    });

    await supabase.rpc("increment_user_credits", {
      user_id_to_update: new_user_id,
      credits_to_add: 1,
    });

    await supabase.from("referrals").insert({
      referrer_id: referrer.id,
      referred_id: new_user_id,
      credits_awarded: creditsForReferrer,
    });

    return new Response(JSON.stringify({ success: true }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : "An unknown error occurred.";
    return new Response(JSON.stringify({ error: errorMessage }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});