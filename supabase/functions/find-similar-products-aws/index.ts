// supabase/functions/find-similar-products-aws/index.ts
// Updated version that uses AWS Lambda/API Gateway for embedding generation
import { serve } from 'std/http/server';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';
import { corsHeaders } from '../_shared/cors.ts';

// AWS Configuration
const AWS_API_URL = Deno.env.get("AWS_EMBEDDING_API_URL") || "";
const AWS_API_KEY = Deno.env.get("AWS_API_KEY") || "";

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: corsHeaders });

  try {
    if (!AWS_API_URL) {
      throw new Error("Missing AWS_EMBEDDING_API_URL environment variable");
    }

    // Get image from request body
    const imageBytes = await req.arrayBuffer();
    
    // Convert to base64
    const base64Image = btoa(
      new Uint8Array(imageBytes).reduce(
        (data, byte) => data + String.fromCharCode(byte),
        ''
      )
    );

    // Prepare headers
    const headers: Record<string, string> = {
      "Content-Type": "application/json",
    };
    
    if (AWS_API_KEY) {
      headers["x-api-key"] = AWS_API_KEY;
    }

    // Call AWS API to generate embedding
    const awsResponse = await fetch(AWS_API_URL, {
      method: "POST",
      headers,
      body: JSON.stringify({
        image_base64: `data:image/jpeg;base64,${base64Image}`
      })
    });

    if (!awsResponse.ok) {
      const err = await awsResponse.text();
      throw new Error(`AWS API Error ${awsResponse.status}: ${err}`);
    }

    const embeddingResponse = await awsResponse.json();
    
    // Handle response format
    let queryEmbedding: number[];
    if (embeddingResponse.body) {
      // API Gateway wraps response in body
      const body = typeof embeddingResponse.body === 'string' 
        ? JSON.parse(embeddingResponse.body) 
        : embeddingResponse.body;
      queryEmbedding = body.embedding || body;
    } else {
      queryEmbedding = embeddingResponse.embedding || embeddingResponse;
    }
    
    // Flatten if nested
    if (queryEmbedding && Array.isArray(queryEmbedding[0]) && !Array.isArray(queryEmbedding[0][0])) {
      queryEmbedding = queryEmbedding[0];
    }

    if (!queryEmbedding || queryEmbedding.length === 0) {
      throw new Error("Failed to generate embedding");
    }

    // Validate dimension
    if (queryEmbedding.length !== 768) {
      console.warn(`Warning: Expected 768 dimensions, got ${queryEmbedding.length}`);
    }

    // Search in Supabase
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

