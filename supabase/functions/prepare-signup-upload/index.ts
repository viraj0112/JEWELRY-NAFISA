import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

type UploadRequestFile = {
  file_type: string;
  ext: string;
  mime_type?: string | null;
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const email = String(body?.email || "").trim().toLowerCase();
    const files = Array.isArray(body?.files) ? body.files : [];

    if (!email || files.length === 0) {
      return new Response(
        JSON.stringify({ error: "Missing email or files." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false } },
    );

    const signupId = crypto.randomUUID();
    const uploads: Array<{ file_type: string; path: string; signed_url: string }> = [];
    const pendingRows: Array<Record<string, unknown>> = [];

    for (const rawFile of files as UploadRequestFile[]) {
      const fileType = String(rawFile?.file_type || "").trim();
      const ext = String(rawFile?.ext || "").replace(".", "").trim().toLowerCase();
      const mimeType = rawFile?.mime_type ?? null;

      if (!fileType || !ext) {
        return new Response(
          JSON.stringify({ error: "Invalid file metadata." }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }
      if (fileType !== "work_file" && fileType !== "business_card") {
        return new Response(
          JSON.stringify({ error: "Unsupported file type." }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      const path = `pending/${signupId}/${fileType}.${ext}`;
      const { data, error } = await supabase.storage
        .from("designer-files")
        .createSignedUploadUrl(path, 600);

      if (error || !data?.signedUrl) {
        throw error ?? new Error("Failed to create signed upload URL.");
      }

      uploads.push({ file_type: fileType, path, signed_url: data.signedUrl });
      pendingRows.push({
        signup_id: signupId,
        email,
        file_type: fileType,
        file_ext: ext,
        object_path: path,
        mime_type: mimeType,
        status: "pending",
      });
    }

    const { error: insertError } = await supabase
      .from("pending_signup_uploads")
      .insert(pendingRows);

    if (insertError) throw insertError;

    return new Response(JSON.stringify({ signup_id: signupId, uploads }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error: unknown) {
    console.error("prepare-signup-upload error:", error);
    const message = error instanceof Error ? error.message : "Unknown error";
    return new Response(JSON.stringify({ error: message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
