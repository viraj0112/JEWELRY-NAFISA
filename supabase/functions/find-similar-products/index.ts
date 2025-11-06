import { serve } from 'std/http/server'
import { createClient } from 'supabase'
import {
  pipeline,
  RawImage,
} from 'transformers'
import { load } from "jsr:@std/dotenv";

const modelName = Deno.env.get("DENO_MODEL_NAME");
const extractor = await pipeline("feature-extraction", modelName);

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
    });
  }
  try {
    const imageBytes = await req.arrayBuffer();
    const image = await RawImage.fromBytes(new Uint8Array(imageBytes));

    const output = await extractor(image, {
      pooling: "mean",
      quantize: false,
    });
    const queryEmbedding = Array.from(output.data);
    const authHeader = req.headers.get("Authorization")!;
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data, error } = await supabase.rpc("search_all_products", {
      query_embedding: queryEmbedding,
      match_threshold: 0.8,
      match_count: 10,
    });

    if (error) throw error;

    return new Response(JSON.stringify(data), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), {
      status: 500,
    });
  }
});
