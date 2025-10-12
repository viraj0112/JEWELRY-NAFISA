import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { assetId } = await req.json();
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // 1. Get the asset from the assets table
    const { data: asset, error: getError } = await supabase
      .from('assets')
      .select('*, users(business_type)')
      .eq('id', assetId)
      .single();

    if (getError) throw getError;

    // 2. Insert into designerproducts table
    const { error: insertError } = await supabase.from('designerproducts').insert({
      designer_id: asset.owner_id,
      title: asset.title,
      description: asset.description,
      image: asset.media_url, // The URL is already correct from the upload step
      price: asset.attributes.Price,
      tags: asset.attributes['Product Tags']?.split(','),
      gold_weight: asset.attributes['Gold Weight'],
      gold_carat: asset.attributes['Metal Purity'],
      gold_finish: asset.attributes['Metal Finish'],
      stone_weight: asset.attributes['Stone Weight'],
      stone_type: asset.attributes['Stone Type'],
      stone_used: asset.attributes['Stone Used'],
      stone_setting: asset.attributes['Stone Setting'],
      stone_purity: asset.attributes['Stone Purity'],
      stone_count: asset.attributes['Stone Count'],
      category: asset.attributes['Product Type'],
      sub_category: asset.attributes['Collection Name'],
      size: asset.attributes['Dimension'],
      occasions: asset.attributes['Theme'],
      style: asset.attributes['Design Type'],
    });

    if (insertError) throw insertError;

    // 3. Update the status of the asset
    await supabase.from('assets').update({ status: 'approved' }).eq('id', assetId);

    return new Response(JSON.stringify({ success: true }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error: unknown) {
    return new Response(JSON.stringify({ error: (error as Error).message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});