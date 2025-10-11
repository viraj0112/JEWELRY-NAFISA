// supabase/functions/approve-product/index.ts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { productId } = await req.json();
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // 1. Get the product from the b2b_products table
    const { data: b2bProduct, error: getError } = await supabase
      .from('b2b_products')
      .select('*')
      .eq('id', productId)
      .single();

    if (getError) throw getError;

    // 2. Move the image
    const oldPath = b2bProduct.media_url.split('/').pop();
    await supabase.storage.from('designer-files').move(oldPath, oldPath);
    const newImageUrl = supabase.storage.from('designer-files').getPublicUrl(oldPath).data.publicUrl;

    // 3. Insert into products table
    await supabase.from('products').insert({
      title: b2bProduct.title,
      description: b2bProduct.description,
      sku: b2bProduct.sku,
      image: newImageUrl,
      // ... other fields
    });

    // 4. Update the status
    await supabase.from('b2b_products').update({ status: 'approved' }).eq('id', productId);
    
    // 5. Send notification email
    // ... (email logic here)


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