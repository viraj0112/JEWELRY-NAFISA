import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.42.0";

// Add this interface
interface UserMetadata {
  referral_code?: string;
}

serve(async (req) => {
  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: {
          headers: { Authorization: `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}` },
        },
      }
    );

    const { record: newUser } = await req.json();

    if (!newUser) {
      console.error("No user data received.");
      return new Response("No user data received.", { status: 400 });
    }

    // Correctly access referral_code from user_metadata
    const metadata = newUser.user_metadata as UserMetadata;
    const referralCode = metadata?.referral_code;

    if (referralCode) {
      const { data: referringUser, error: referringUserError } = await supabase
        .from("users")
        .select("id, is_member")
        .eq("referral_code", referralCode)
        .single();

      if (referringUserError) {
        console.error("Error finding referring user:", referringUserError);
        return new Response("Error finding referring user.", { status: 500 });
      }

      if (referringUser) {
        // Get credit settings
        const { data: settings, error: settingsError } = await supabase
          .from("admin_settings")
          .select("referral_credits_member, referral_credits_non_member, new_user_credits_on_referral")
          .single();

        if (settingsError) {
          console.error("Error fetching admin settings:", settingsError);
          return new Response("Error fetching admin settings.", { status: 500 });
        }

        const creditsForReferrer = referringUser.is_member
          ? settings.referral_credits_member
          : settings.referral_credits_non_member;

        const { error: referrerUpdateError } = await supabase.rpc(
          "increment_user_credits",
          {
            user_id: referringUser.id,
            credits_to_add: creditsForReferrer,
          }
        );
        if (referrerUpdateError) {
          console.error("Error updating referrer credits:", referrerUpdateError);
        }

        const { error: newUserUpdateError } = await supabase.rpc(
          "increment_user_credits",
          {
            user_id: newUser.id,
            credits_to_add: settings.new_user_credits_on_referral,
          }
        );

        if (newUserUpdateError) {
          console.error("Error updating new user credits:", newUserUpdateError);
        }
      }
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("An unexpected error occurred:", error);
    return new Response("Internal Server Error", { status: 500 });
  }
});