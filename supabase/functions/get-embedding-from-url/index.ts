// supabase/functions/get-embedding-from-url/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Config
const HF_API_URL = "https://api-inference.huggingface.co/models/sentence-transformers/clip-ViT-B-32";

serve(async (req) => {
  try {
    // 1. Validate Secrets
    const hfToken = Deno.env.get("HUGGING_FACE_TOKEN");
    const sbUrl = Deno.env.get("SUPABASE_URL");
    const sbKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!hfToken || !sbUrl || !sbKey) {
      throw new Error("Missing environment variables (HUGGING_FACE_TOKEN, SUPABASE_URL, or SUPABASE_SERVICE_ROLE_KEY)");
    }

    // 2. Parse Request
    const { table = 'products' } = await req.json().catch(() => ({}));
    console.log(`Processing batch for table: ${table}`);

    // 3. Init Supabase
    const supabase = createClient(sbUrl, sbKey);

    // 4. Fetch Items (Batch of 5)
    // FIX: We map "Product Title" to 'title' and "Image" to 'image' using aliasing
    const { data: items, error: fetchError } = await supabase
      .from(table)
      .select('id, title:"Product Title", image:Image') 
      .is('embedding', null)
      .not('Image', 'is', null) // Ensure we don't pick items without images
      .limit(5);

    if (fetchError) throw new Error(`Supabase Fetch Error: ${fetchError.message}`);
    
    if (!items || items.length === 0) {
      return new Response(JSON.stringify({ message: `No more items to process in ${table}!` }), { 
        headers: { "Content-Type": "application/json" } 
      });
    }

    // 5. Generate Embeddings
    const results = [];
    for (const item of items) {
      try {
        if (!item.image) {
           console.log(`Skipping ${item.id} (No Image)`);
           continue;
        }

        // Fetch Image
        const imgRes = await fetch(item.image);
        if (!imgRes.ok) throw new Error(`Image download failed: ${imgRes.statusText}`);
        const imgBlob = await imgRes.blob();

        // Call Hugging Face
        const hfRes = await fetch(HF_API_URL, {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${hfToken}`,
            "Content-Type": "application/octet-stream",
            "x-wait-for-model": "true"
          },
          body: imgBlob
        });

        if (!hfRes.ok) {
           const errText = await hfRes.text();
           throw new Error(`HF API Error: ${errText}`);
        }

        const json = await hfRes.json();
        // Handle HF response variations
        let vector = json;
        if (json.embeddings) vector = json.embeddings; 
        if (Array.isArray(json) && Array.isArray(json[0])) vector = json[0];

        // Save to DB
        const { error: updateError } = await supabase
          .from(table)
          .update({ embedding: vector })
          .eq('id', item.id);

        if (updateError) throw new Error(`DB Update Error: ${updateError.message}`);
        
        results.push({ id: item.id, status: "Success" });

      } catch (innerErr) {
        console.error(`Item ${item.id} failed:`, innerErr);
        results.push({ id: item.id, status: "Failed", error: String(innerErr) });
      }
    }

    return new Response(JSON.stringify({ processed: results }), {
      headers: { "Content-Type": "application/json" },
    });

  } catch (e) {
    console.error("Fatal Function Error:", e);
    return new Response(JSON.stringify({ 
      error: e instanceof Error ? e.message : String(e) 
    }), { 
      status: 500,
      headers: { "Content-Type": "application/json" } 
    });
  }
});