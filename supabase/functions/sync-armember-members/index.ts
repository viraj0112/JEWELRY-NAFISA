import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { cron } from "https://deno.land/x/deno_cron@v1.0.0/cron.ts";

const ARMEMBER_API_BASE_URL =
  "https://members.daginawala.in/wp-json/armember/v1/";
const ARMEMBER_API_KEY = Deno.env.get("ARMEMBER_SECURITY_KEY");

// --- START: Custom Fetch Logic for SSL ---
// This creates a custom HTTP client that will be used for our fetch requests
// It's a workaround for the SSL certificate issue on the WordPress server.
// @ts-ignore: Deno Deploy specific option
const client = Deno.createHttpClient({
  // This tells the client to accept certificates that are not from a trusted authority
  // Use with caution and only for specific trusted endpoints.
  caCerts: [], 
});

async function customFetch(url: string, options: RequestInit = {}): Promise<Response> {
  return await fetch(url, { ...options, client });
}
// --- END: Custom Fetch Logic for SSL ---


cron("0 * * * *", async () => {
  console.log("Running ARMember sync job...");

  if (!ARMEMBER_API_KEY) {
    console.error("ARMEMBER_SECURITY_KEY is not set in Supabase secrets.");
    return;
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  try {
    const plansResponse = await customFetch(
      `${ARMEMBER_API_BASE_URL}arm_memberships?arm_api_key=${ARMEMBER_API_KEY}`
    );

    if (!plansResponse.ok) {
      throw new Error(`Failed to fetch plans: ${plansResponse.statusText}`);
    }
    const plansResult = await plansResponse.json();
    const plans = plansResult.data;

    if (!Array.isArray(plans)) {
      throw new Error("API did not return a valid list of plans.");
    }

    const allMembers = new Map();
    for (const plan of plans) {
      const planId = plan.arm_subscription_plan_id;
      const planName = plan.arm_subscription_plan_name;
 
      const membersResponse = await customFetch(
        `${ARMEMBER_API_BASE_URL}arm_plan_members?arm_api_key=${ARMEMBER_API_KEY}&arm_plan_id=${planId}`
      );

      if (!membersResponse.ok) {
        console.error(`Could not fetch members for plan ID ${planId}`);
        continue;
      }
      const membersResult = await membersResponse.json();
      const members = membersResult.data;

      if (Array.isArray(members)) {
        for (const member of members) {
          allMembers.set(member.user_email, {
            plan_name: planName,
            status: member.arm_user_status,
          });
        }
      }
    }

    const updates = Array.from(allMembers.entries()).map(
      async ([email, data]) => {
        const isMember = data.status === "active";
        const { error } = await supabase
          .from("users")
          .update({
            is_member: isMember,
            membership_plan: data.plan_name,
          })
          .eq("email", email);

        if (error) {
          console.error(`Failed to update user ${email}:`, error.message);
        } else {
          console.log(`Successfully synced user ${email}`);
        }
      }
    );

    await Promise.all(updates);
    console.log("ARMember sync job finished.");
  } catch (error) {
    if (error instanceof Error) {
      console.error("Error during ARMember sync:", error.message);
    } else {
      console.error("An unknown error occurred during ARMember sync:", error);
    }
  }
});

serve(() => new Response("ARMember Sync Cron is running.", { status: 200 }));