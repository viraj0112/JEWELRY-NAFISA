import { serve } from 'std/http/server';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';
import { corsHeaders } from '../_shared/cors.ts';

// OPTIMIZATION: Use the most popular CLIP model (High chance of being cached/warm)
const HF_API_URL = "https://api-inference.huggingface.co/models/sentence-transformers/clip-ViT-B-32";
const HF_TOKEN = Deno.env.get("HUGGING_FACE_TOKEN");

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: corsHeaders });

  try {
    if (!HF_TOKEN) throw new Error("Missing HUGGING_FACE_TOKEN");

    const imageBytes = await req.arrayBuffer();

    const hfResponse = await fetch(HF_API_URL, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${HF_TOKEN}`,
        "Content-Type": "application/octet-stream",
        "x-use-cache": "true", 
        "x-wait-for-model": "true" 
      },
      body: imageBytes
    });

    if (!hfResponse.ok) {
      const err = await hfResponse.text();
      throw new Error(`HF Error ${hfResponse.status}: ${err}`);
    }

    const embeddingResponse = await hfResponse.json();
    

    let queryEmbedding;
    if (Array.isArray(embeddingResponse)) {
      queryEmbedding = embeddingResponse;
    } else if (embeddingResponse.embeddings) {
      queryEmbedding = embeddingResponse.embeddings;
    }
    
    // Flatten if it's nested [[0.1, 0.2...]]
    if (queryEmbedding && Array.isArray(queryEmbedding[0])) {
      queryEmbedding = queryEmbedding[0];
    }

    if (!queryEmbedding || queryEmbedding.length === 0) {
       throw new Error("Failed to generate embedding");
    }

  
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "" 
    );

    const { data, error } = await supabase.rpc("search_all_products", {
      query_embedding: queryEmbedding,
      match_threshold: 0.75, 
      match_count: 15
    });

    if (error) throw error;

    return new Response(JSON.stringify(data), {
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });

  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });
  }
});