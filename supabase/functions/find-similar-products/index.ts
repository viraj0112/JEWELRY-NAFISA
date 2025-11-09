import { serve } from 'std/http/server';
import { createClient } from 'supabase';
import { corsHeaders } from '../_shared/cors.ts';
// Use Serverless Inference API endpoint (new Hugging Face infrastructure)
const HF_API_URL = "https://api-inference.huggingface.co/models/openai/clip-vit-base-patch32";
const HF_TOKEN = Deno.env.get("HUGGING_FACE_TOKEN");
serve(async (req)=>{
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: corsHeaders
    });
  }
  if (req.method !== "POST") {
    return new Response(JSON.stringify({
      error: "Method not allowed"
    }), {
      status: 405,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  }
  try {
    if (!HF_TOKEN) {
      throw new Error("HUGGING_FACE_TOKEN environment variable not set. Get one from https://huggingface.co/settings/tokens");
    }
    const imageBytes = await req.arrayBuffer();
    // Send raw image bytes directly to the API
    const hfResponse = await fetch(HF_API_URL, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${HF_TOKEN}`,
        "Content-Type": "application/octet-stream"
      },
      body: imageBytes
    });
    if (!hfResponse.ok) {
      const errorText = await hfResponse.text();
      console.error("HF API Error:", hfResponse.status, errorText);
      // If model is loading, suggest retry
      if (hfResponse.status === 503) {
        throw new Error("Model is loading. Please wait 10-20 seconds and try again.");
      }
      throw new Error(`Hugging Face API error (${hfResponse.status}): ${errorText.substring(0, 300)}`);
    }
    // Get the embedding from HF response
    const embedding = await hfResponse.json();
    // Extract embedding array - HF Serverless API returns different formats
    let queryEmbedding;
    if (Array.isArray(embedding)) {
      // Direct array or array of arrays
      queryEmbedding = Array.isArray(embedding[0]) ? embedding[0] : embedding;
    } else if (embedding.embeddings && Array.isArray(embedding.embeddings)) {
      queryEmbedding = embedding.embeddings[0];
    } else if (embedding.data && Array.isArray(embedding.data)) {
      queryEmbedding = embedding.data;
    } else {
      console.error("Unexpected embedding format:", JSON.stringify(embedding).substring(0, 200));
      throw new Error("Unexpected embedding format from Hugging Face API");
    }
    console.log("Embedding length:", queryEmbedding.length);
    const authHeader = req.headers.get("Authorization");
    const supabase = createClient(Deno.env.get("SUPABASE_URL") ?? "", Deno.env.get("SUPABASE_ANON_KEY") ?? "", {
      global: {
        headers: {
          Authorization: authHeader
        }
      }
    });
    const { data, error } = await supabase.rpc("search_all_products", {
      query_embedding: queryEmbedding,
      match_threshold: 0.78,
      match_count: 10
    });
    if (error) throw error;
    return new Response(JSON.stringify(data), {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  } catch (e) {
    console.error("Error in find-similar-products:", e);
    return new Response(JSON.stringify({
      error: e.message || "Unknown error",
      details: e.toString(),
      stack: e.stack,
      hint: HF_TOKEN ? "Ensure 'Make calls to Inference Providers' permission is enabled for your token at https://huggingface.co/settings/tokens" : "HUGGING_FACE_TOKEN environment variable not set"
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  }
});
