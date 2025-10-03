import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.0.0";

serve(async (req) => {
  try {
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: {
          headers: {
            Authorization: `Bearer ${Deno.env.get(
              "SUPABASE_SERVICE_ROLE_KEY"
            )}`,
          },
        },
      }
    );

    const { record } = await req.json();

    const channel = supabaseClient.channel("dashboard");
    await channel.send({
      type: "broadcast",
      event: "metrics-update",
      payload: { record },
    });

    return new Response(
      JSON.stringify({ message: "Metrics update broadcasted" }),
      { headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    const errorMessage = err instanceof Error ? err.message : String(err);
    return new Response(errorMessage, { status: 500 });
  }
});
