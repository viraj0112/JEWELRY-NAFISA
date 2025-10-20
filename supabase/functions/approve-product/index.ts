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
    // Maps fields from the 'assets' table (and its attributes JSONB) to the 'designerproducts' table
    const { error: insertError } = await supabase
      .from("designerproducts")
      .insert({
        designer_id: asset.owner_id,
        title: asset.title,
        description: asset.description,
        image: asset.media_url,
        price: asset.attributes?.Price,
        tags: asset.attributes?.["Product Tags"]
          ?.split(",")
          .map((t: string) => t.trim()), // Split tags string into an array
        gold_weight: asset.attributes?.["Gold Weight"],
        gold_carat: asset.attributes?.["Metal Purity"],
        gold_finish: asset.attributes?.["Metal Finish"],
        stone_weight: asset.attributes?.["Stone Weight"],
        stone_type: asset.attributes?.["Stone Type"],
        stone_used: asset.attributes?.["Stone Used"],
        stone_setting: asset.attributes?.["Stone Setting"],
        stone_purity: asset.attributes?.["Stone Purity"],
        stone_count: asset.attributes?.["Stone Count"],
        category: asset.attributes?.["Product Type"],
        sub_category: asset.attributes?.["Collection Name"],
        size: asset.attributes?.["Dimension"],
        occasions: asset.attributes?.["Theme"],
        style: asset.attributes?.["Design Type"],
        // NOTE: Ensure all required fields in 'designerproducts' are present in 'assets.attributes'
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
