import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Extract assetId from the request body
    const { assetId } = await req.json();

    // Initialize Supabase client using environment variables
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, // Use service role key for admin privileges
      { auth: { persistSession: false } } // Ensure no session persistence server-side
    );

    // 1. Get the asset. The destination table comes from asset.source, so the
    // old designer_profiles join (which could not describe a manufacturer
    // submission anyway) is no longer needed.
    const { data: asset, error: getError } = await supabase
      .from("assets")
      .select("*")
      .eq("id", assetId)
      .single(); // Expecting only one asset

    // Handle potential errors during asset fetch
    if (getError) throw getError;

    const { error: userUpdateError } = await supabase
      .from("users")
      .update({ is_approved: true })
      .eq("id", asset.owner_id);

    // Handle potential errors during user update
    if (userUpdateError) throw userUpdateError;

    // 2. Publish the approved asset into the real product table, mapping the
    // assets row + its attributes JSONB onto the Phase-3 column contract.
    // Helper: attributes values may already be an array, or a comma-separated string.
    const toArray = (v: unknown): string[] | null => {
      if (v == null) return null;
      if (Array.isArray(v)) return v;
      if (typeof v === "string") {
        return v.split(",").map((t) => t.trim()).filter((t) => t.length > 0);
      }
      return null;
    };

    // Publish to the table the submission came from. Uploads record the
    // destination in `source` (see sinlgeFile.dart / bulkUpload.dart); anything
    // else (e.g. 'bulk_admin', legacy 'uploaded') is a designer submission.
    const targetTable =
      asset.source === "manufacturerproducts"
        ? "manufacturerproducts"
        : "designerproducts";

    // Bulk upload stashes the full ordered image list in attributes because
    // assets.media_url only holds one. Fall back to media_url for submissions
    // that predate that (or came from the admin screen).
    const attributeImages = toArray(asset.attributes?.["Images"]);
    const images = attributeImages ?? (asset.media_url ? [asset.media_url] : []);

    // Phase 3 dropped "Image"/"Gold Weight"/"Design Type"/"Collection Name" and
    // renamed images_arr/metal_color_arr/category_arr to "Images"/"Metal
    // Color"/"Category" (text[]). Writing the old names made every approval
    // fail with "column does not exist".
    const { error: insertError } = await supabase
      .from(targetTable)
      .insert({
        user_id: asset.owner_id,
        "Product Title": asset.title,
        Description: asset.description,
        Images: images,
        Price: asset.attributes?.Price,
        "Product Tags": toArray(asset.attributes?.["Product Tags"]),
        "Metal Weight": asset.attributes?.["Metal Weight"],
        "Metal Purity": asset.attributes?.["Metal Purity"],
        "Metal Finish": asset.attributes?.["Metal Finish"],
        "Metal Type": asset.attributes?.["Metal Type"],
        "Metal Color": toArray(asset.attributes?.["Metal Color"]),
        "Stone Weight": toArray(asset.attributes?.["Stone Weight"]),
        "Stone Type": toArray(asset.attributes?.["Stone Type"]),
        "Stone Used": toArray(asset.attributes?.["Stone Used"]),
        "Stone Setting": toArray(asset.attributes?.["Stone Setting"]),
        "Stone Purity": toArray(asset.attributes?.["Stone Purity"]),
        "Stone Count": toArray(asset.attributes?.["Stone Count"]),
        "Stone Color": toArray(asset.attributes?.["Stone Color"]),
        "Stone Cut": toArray(asset.attributes?.["Stone Cut"]),
        Category: toArray(asset.attributes?.["Category"]) ??
          (asset.category ? [asset.category] : null),
        "Product Type": asset.attributes?.["Product Type"] ?? asset.category,
        "Sub Category": asset.attributes?.["Sub Category"],
        Dimension: asset.attributes?.["Dimension"],
        Theme: asset.attributes?.["Theme"],
        Gender: asset.attributes?.["Gender"],
        Plating: asset.attributes?.["Plating"],
        Plain: asset.attributes?.["Plain"],
        Studded: toArray(asset.attributes?.["Studded"]),
        "Enamel Work": toArray(asset.attributes?.["Enamel Work"]),
        Customizable: toArray(asset.attributes?.["Customizable"]),
      });

    // Handle potential errors during product insertion
    if (insertError) throw insertError;

    // 3. Update the status of the original asset in the 'assets' table to 'approved'
    const { error: assetUpdateError } = await supabase
      .from("assets")
      .update({ status: "approved" })
      .eq("id", assetId);

    // Handle potential errors during asset status update
    if (assetUpdateError) throw assetUpdateError;

    // Return a success response if everything went well
    return new Response(JSON.stringify({ success: true }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200, // Explicitly set status to 200 OK
    });
  } catch (error: unknown) {
    // Log the error for server-side debugging
    console.error("Error processing approve-product request:", error);

    // Return a generic error response to the client
    // Extracts the error message safely
    const errorMessage =
      error instanceof Error ? error.message : "An unknown error occurred.";
    return new Response(JSON.stringify({ error: errorMessage }), {
      status: 400, // Use 400 for client-related errors (like missing data) or 500 for server errors
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
