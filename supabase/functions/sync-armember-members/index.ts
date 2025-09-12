import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

const ARMEMBER_API_BASE_URL = "https://members.daginawala.in/wp-json/armember/v1/";
const ARMEMBER_API_KEY = Deno.env.get("ARMEMBER_SECURITY_KEY");

interface ARMember {
  plan_name: string;
  status: string;
}

async function runARMemberSync() {
  console.log("--- Running Full ARMember Sync Job ---");
  if (!ARMEMBER_API_KEY) {
    console.error("ARMEMBER_SECURITY_KEY is not set.");
    return;
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  try {
    const allMembersResponse = await fetch(
      `${ARMEMBER_API_BASE_URL}arm_members?arm_api_key=${ARMEMBER_API_KEY}`
    );
    if (!allMembersResponse.ok) throw new Error("Failed to fetch members from ARMember.");
    
    const membersResult = await allMembersResponse.json();

    const armMembers = new Map<string, ARMember>(
      membersResult.data.map((m: any) => [
        m.user_email,
        { plan_name: m.arm_subscription_plan_name, status: m.arm_user_status },
      ])
    );
    console.log(`Found ${armMembers.size} total members in ARMember.`);

    const { data: supabaseUsers, error: fetchError } = await supabase
      .from("users")
      .select("email, is_member, membership_plan, membership_status");

    if (fetchError) throw fetchError;

    const updates = [];
    for (const user of supabaseUsers) {
      const armMember = armMembers.get(user.email);
      const isMemberInArm = armMember?.status === "active";

      if (armMember) {
        if (user.is_member !== isMemberInArm || user.membership_plan !== armMember.plan_name) {
          updates.push({
            email: user.email,
            is_member: isMemberInArm,
            membership_plan: armMember.plan_name,
            membership_status: armMember.status,
          });
        }
        armMembers.delete(user.email);
      } else if (user.is_member) {
        updates.push({
          email: user.email,
          is_member: false,
          membership_plan: null,
          membership_status: 'cancelled_or_expired',
        });
      }
    }

    console.log(`Preparing to update ${updates.length} records in Supabase...`);

    for (const update of updates) {
      await supabase
        .from("users")
        .update({
          is_member: update.is_member,
          membership_plan: update.membership_plan,
          membership_status: update.membership_status,
        })
        .eq("email", update.email);
    }

    console.log("--- ARMember full sync finished successfully! ---");

  } catch (error) {
    if (error instanceof Error) {
      console.error("Error during ARMember sync:", error.message);
    } else {
      console.error("An unknown error occurred during ARMember sync:", error);
    }
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method === "POST") {
    runARMemberSync(); 
    return new Response(JSON.stringify({ message: "Sync triggered." }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
  return new Response("ARMember Sync Cron is running.", {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});