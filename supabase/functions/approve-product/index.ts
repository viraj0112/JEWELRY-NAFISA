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

    // 1. Get the asset details and the owner's business type
    // Joins assets -> users (aliased as 'owner') -> designer_profiles
    const { data: asset, error: getError } = await supabase
      .from("assets")
      // Select all asset fields, and join through users (owner_id) to designer_profiles to get business_type
      .select("*, owner:users!owner_id(designer_profiles(business_type))") // <--- CORRECTED JOIN
      .eq("id", assetId)
      .single(); // Expecting only one asset

    // Handle potential errors during asset fetch
    if (getError) throw getError;

    // Safely access the business type
    // The optional chaining (?.) prevents errors if 'owner' or 'designer_profiles' is null
    const businessType = asset.owner?.designer_profiles?.business_type;
    const { error: userUpdateError } = await supabase
      .from("users")
      .update({ is_approved: true })
      .eq("id", asset.owner_id);

    // Handle potential errors during user update
    if (userUpdateError) throw userUpdateError;

    // 2. Insert the approved asset data into the designerproducts table
    // Maps fields from the 'assets' table (and its attributes JSONB) to the real
    // designerproducts columns (PascalCase legacy + Phase-1 unified array columns).
    // Helper: attributes values may already be an array, or a comma-separated string.
    const toArray = (v: unknown): string[] | null => {
      if (v == null) return null;
      if (Array.isArray(v)) return v;
      if (typeof v === "string") {
        return v.split(",").map((t) => t.trim()).filter((t) => t.length > 0);
      }
      return null;
    };

    const image = asset.media_url ? [asset.media_url] : [];
    const goldWeight = asset.attributes?.["Gold Weight"];
    const metalColor = asset.attributes?.["Metal Color"];

    const { error: insertError } = await supabase
      .from("designerproducts")
      .insert({
        user_id: asset.owner_id,
        "Product Title": asset.title,
        Description: asset.description,
        Image: image,
        images_arr: image,
        Price: asset.attributes?.Price,
        "Product Tags": toArray(asset.attributes?.["Product Tags"]),
        "Gold Weight": goldWeight,
        "Metal Weight": goldWeight,
        "Metal Purity": asset.attributes?.["Metal Purity"],
        "Metal Finish": asset.attributes?.["Metal Finish"],
        "Metal Type": asset.attributes?.["Metal Type"],
        "Metal Color": metalColor,
        metal_color_arr: metalColor ? [metalColor] : null,
        "Stone Weight": toArray(asset.attributes?.["Stone Weight"]),
        "Stone Type": toArray(asset.attributes?.["Stone Type"]),
        "Stone Used": toArray(asset.attributes?.["Stone Used"]),
        "Stone Setting": toArray(asset.attributes?.["Stone Setting"]),
        "Stone Purity": toArray(asset.attributes?.["Stone Purity"]),
        "Stone Count": toArray(asset.attributes?.["Stone Count"]),
        Category: asset.category,
        category_arr: asset.category ? [asset.category] : null,
        "Product Type": asset.attributes?.["Product Type"],
        "Sub Category": asset.attributes?.["Collection Name"],
        Dimension: asset.attributes?.["Dimension"],
        Theme: asset.attributes?.["Theme"],
        "Design Type": asset.attributes?.["Design Type"],
        // NOTE: Plain, Studded, Enamel Work, Customizable, Stone Cut, Stone Color,
        // Art Form, Plating, Scraped URL are not derivable from assets/attributes
        // today and are left null (all nullable columns).
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
