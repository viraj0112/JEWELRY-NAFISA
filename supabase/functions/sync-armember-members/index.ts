import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { cron } from "https://deno.land/x/deno_cron@v1.0.0/cron.ts";
import { corsHeaders } from "../_shared/cors.ts";

const ARMEMBER_API_BASE_URL =
  "https://members.daginawala.in/wp-json/armember/v1/";
const ARMEMBER_API_KEY = Deno.env.get("ARMEMBER_SECURITY_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;

async function runARMemberSync() {
  console.log("--- Running ARMember sync job... ---");

  if (!ARMEMBER_API_KEY) {
    console.error(
      "!!! FATAL: ARMEMBER_SECURITY_KEY is not set in Supabase secrets."
    );
    return;
  }

  const supabase = createClient(
    SUPABASE_URL,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  try {
    console.log("Step 1: Fetching membership plans from ARMember...");
    const plansResponse = await fetch(
      `${ARMEMBER_API_BASE_URL}arm_memberships?arm_api_key=${ARMEMBER_API_KEY}`
    );

    if (!plansResponse.ok) {
      throw new Error(
        `Failed to fetch plans: ${
          plansResponse.statusText
        } - ${await plansResponse.text()}`
      );
    }
    const plansResult = await plansResponse.json();
    const plans = plansResult.data;

    if (!Array.isArray(plans) || plans.length === 0) {
      console.log("!!! No membership plans found in ARMember. Exiting job.");
      return;
    }

    console.log(
      `--> Success! Found ${plans.length} plans:`,
      plans.map((p) => p.arm_subscription_plan_name).join(", ")
    );
    console.log("Step 2: Iterating through each plan to find members...");

    const allMembers = new Map();
    for (const plan of plans) {
      const planId = plan.arm_subscription_plan_id;
      const planName = plan.arm_subscription_plan_name;
      console.log(`\n--- Processing Plan: "${planName}" (ID: ${planId}) ---`);

      const membersResponse = await fetch(
        `${ARMEMBER_API_BASE_URL}arm_plan_members?arm_api_key=${ARMEMBER_API_KEY}&arm_plan_id=${planId}`
      );

      if (!membersResponse.ok) {
        console.error(
          `!!! Could not fetch members for plan ID ${planId}. Skipping.`
        );
        continue;
      }
      const membersResult = await membersResponse.json();
      const members = membersResult.data;

      if (Array.isArray(members) && members.length > 0) {
        console.log(`--> Found ${members.length} members in this plan.`);
        for (const member of members) {
          console.log(
            `   - Processing member: ${member.user_login} (${member.user_email}) with status: ${member.arm_user_status}`
          );
          allMembers.set(member.user_email, {
            plan_name: planName,
            status: member.arm_user_status,
          });
        }
      } else {
        console.log("--> No members found in this plan.");
      }
    }

    console.log(
      `\nStep 3: Found a total of ${allMembers.size} unique members across all plans. Preparing to update Supabase...`
    );

    if (allMembers.size === 0) {
      console.log("No members to update. ARMember sync job finished.");
      return;
    }

    const updates = Array.from(allMembers.entries()).map(
      async ([email, data]) => {
        const isMember = data.status === "active";
        console.log(
          `- Updating user ${email}: Setting is_member to ${isMember} with plan "${data.plan_name}"`
        );
        const { error } = await supabase
          .from("users")
          .update({
            is_member: isMember,
            membership_plan: data.plan_name,
          })
          .eq("email", email);

        if (error) {
          console.error(`!!! FAILED to update user ${email}:`, error.message);
        }
      }
    );

    await Promise.all(updates);
    console.log("\n--- ARMember sync job finished successfully! ---");
  } catch (error) {
    if (error instanceof Error) {
      console.error(
        "!!! An unexpected error occurred during ARMember sync:",
        error.message
      );
    } else {
      console.error(
        "!!! An unknown and unexpected error occurred during ARMember sync:",
        error
      );
    }
  }
}

cron("0 * * * *", runARMemberSync);

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method === "POST") {
    runARMemberSync(); // Call our main function
    return new Response(
      JSON.stringify({ message: "Sync triggered. Check server logs." }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }

  return new Response("ARMember Sync Cron is running.", {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
