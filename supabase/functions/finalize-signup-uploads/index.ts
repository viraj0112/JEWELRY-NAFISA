import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing auth." }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = await req.json();
    const signupId = String(body?.signup_id || "").trim();
    if (!signupId) {
      return new Response(JSON.stringify({ error: "Missing signup_id." }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;

    const authClient = createClient(supabaseUrl, anonKey, {
      auth: { persistSession: false },
      global: { headers: { Authorization: authHeader } },
    });
    const { data: authData, error: authError } = await authClient.auth.getUser();
    if (authError || !authData?.user?.id || !authData.user.email) {
      return new Response(JSON.stringify({ error: "Invalid auth." }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const userId = authData.user.id;
    const userEmail = authData.user.email.toLowerCase();

    const supabase = createClient(
      supabaseUrl,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false } },
    );

    const { data: pending, error: pendingError } = await supabase
      .from("pending_signup_uploads")
      .select("*")
      .eq("signup_id", signupId)
      .eq("email", userEmail)
      .eq("status", "pending");

    if (pendingError) throw pendingError;
    if (!pending || pending.length === 0) {
      return new Response(JSON.stringify({ error: "No pending uploads." }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const insertedRows: Array<Record<string, unknown>> = [];

    for (const row of pending) {
      const fileType = row.file_type as string;
      const fileExt = row.file_ext as string;
      const objectPath = row.object_path as string;
      const newPath = `users/${userId}/${fileType}.${fileExt}`;

      const { error: moveError } = await supabase.storage
        .from("designer-files")
        .move(objectPath, newPath);
      if (moveError) throw moveError;

      const { data: publicData } = supabase.storage
        .from("designer-files")
        .getPublicUrl(newPath);

      insertedRows.push({
        user_id: userId,
        file_type: fileType,
        file_url: publicData.publicUrl,
      });
    }

    const { error: insertError } = await supabase
      .from("designer-files")
      .insert(insertedRows);
    if (insertError) throw insertError;

    const { error: updateError } = await supabase
      .from("pending_signup_uploads")
      .update({
        status: "linked",
        linked_user_id: userId,
        linked_at: new Date().toISOString(),
      })
      .eq("signup_id", signupId)
      .eq("email", userEmail)
      .eq("status", "pending");
    if (updateError) throw updateError;

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error: unknown) {
    console.error("finalize-signup-uploads error:", error);
    const message = error instanceof Error ? error.message : "Unknown error";
    return new Response(JSON.stringify({ error: message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
