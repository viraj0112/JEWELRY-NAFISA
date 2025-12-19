// supabase/functions/get-embedding-from-url-aws/index.ts
// Updated version that uses AWS Lambda/API Gateway instead of Hugging Face
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// AWS Configuration
const AWS_API_URL = Deno.env.get("AWS_EMBEDDING_API_URL") || "";
const AWS_API_KEY = Deno.env.get("AWS_API_KEY") || "";

serve(async (req) => {
  try {
    // 1. Validate Secrets
    if (!AWS_API_URL) {
      throw new Error("Missing AWS_EMBEDDING_API_URL environment variable");
    }

    const sbUrl = Deno.env.get("SUPABASE_URL");
    const sbKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!sbUrl || !sbKey) {
      throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
    }

    // 2. Parse Request
    const { table = 'products' } = await req.json().catch(() => ({}));
    console.log(`Processing batch for table: ${table}`);

    // 3. Init Supabase
    const supabase = createClient(sbUrl, sbKey);

    // 4. Fetch Items (Batch of 5)
    const { data: items, error: fetchError } = await supabase
      .from(table)
      .select('id, "Product Title", Image')
      .is('embedding', null)
      .not('Image', 'is', null)
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
        const imageUrl = Array.isArray(item.Image) ? item.Image[0] : item.Image;
        
        if (!imageUrl) {
          console.log(`Skipping ${item.id} (No Image)`);
          continue;
        }

        // Call AWS API
        const headers: Record<string, string> = {
          "Content-Type": "application/json",
        };
        
        if (AWS_API_KEY) {
          headers["x-api-key"] = AWS_API_KEY;
        }

        const awsRes = await fetch(AWS_API_URL, {
          method: "POST",
          headers,
          body: JSON.stringify({
            image_url: imageUrl
          })
        });

        if (!awsRes.ok) {
          const errText = await awsRes.text();
          throw new Error(`AWS API Error (${awsRes.status}): ${errText}`);
        }

        const json = await awsRes.json();
        
        // Handle response format
        let vector: number[];
        if (json.body) {
          // API Gateway wraps response in body
          const body = typeof json.body === 'string' ? JSON.parse(json.body) : json.body;
          vector = body.embedding || body;
        } else {
          vector = json.embedding || json;
        }

        if (!Array.isArray(vector) || vector.length === 0) {
          throw new Error("Invalid embedding format received from AWS");
        }

        // Validate dimension (should be 768 for Dinov2-base)
        if (vector.length !== 768) {
          console.warn(`Warning: Expected 768 dimensions, got ${vector.length}`);
        }

        // Save to DB
        const { error: updateError } = await supabase
          .from(table)
          .update({ embedding: vector })
          .eq('id', item.id);

        if (updateError) throw new Error(`DB Update Error: ${updateError.message}`);
        
        results.push({ id: item.id, status: "Success", dimension: vector.length });

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

