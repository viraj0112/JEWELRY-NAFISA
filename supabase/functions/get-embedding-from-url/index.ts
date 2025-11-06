import { serve } from "std/http/server";
import { pipeline, RawImage } from "transformers";
import { load } from "jsr:@std/dotenv";

const modelName = Deno.env.get("DENO_MODEL_NAME");
const extractor = await pipeline("feature-extraction", modelName);

serve(async (req) => {
  const { imageUrl } = await req.json();
  if (!imageUrl) {
    return new Response(JSON.stringify({ error: "imageUrl is required" }), {
      status: 400,
    });
  }
  try {
    const image = await RawImage.fromURL(imageUrl);
    const output = await extractor(image, {
      pooling: "mean",
      quantize: false,
    });
    const embedding = Array.from(output.data);
    return new Response(JSON.stringify({ embedding: embedding }), {
      status: 200,
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), { status: 500 });
  }
});
