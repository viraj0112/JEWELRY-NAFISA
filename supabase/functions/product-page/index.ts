// [This is the corrected code for: supabase/functions/product-page/index.ts]

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts"; // Import CORS headers

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  
  const url = new URL(req.url);
  const pathSegments = url.pathname.split("/");

  // Use .pop() to get the last segment, which should be the slug
  const productSlug = pathSegments.pop() || pathSegments.pop();
  
  if (!productSlug || productSlug === "product-page") {
    return new Response(
      JSON.stringify({ error: "Product slug missing in URL" }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      }
    );
  }
  
  // <-- FIX: Re-create a fuzzy search term from the slug
  // "hearty-bliss-gemstone-pendant" -> "hearty%bliss%gemstone%pendant"
  const productSearchTerm = productSlug.replaceAll('-', '%');

  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  let productData: any = null;
  let error: any = null;

  // --- Search for the product by title in both tables ---
  // We use 'ilike' for a case-insensitive match
  let { data: prodData, error: prodError } = await supabase
    .from("products")
    .select('"Product Title", "Description", "Image"')
    .ilike('"Product Title"', productSearchTerm) // <-- FIX: Use fuzzy search term
    .maybeSingle();

  if (prodData) {
    productData = prodData;
  } else {
    // If not in 'products', check 'designerproducts'
    let { data: designerProdData, error: designerProdError } = await supabase
      .from("designerproducts")
      .select('"Product Title", "description", "image"')
      .ilike('"Product Title"', productSearchTerm) // <-- FIX: Use fuzzy search term
      .maybeSingle();

    if (designerProdData) {
      // Map designer product fields to match standard product fields
      productData = {
        "Product Title": designerProdData["Product Title"],
        "Description": designerProdData["description"], 
        "Image": designerProdData["image"],
      };
    } else {
      // If not found in either, set the error
      error = designerProdError || prodError || new Error("Product not found");
    }
  }

  if (error || !productData) {
    console.error(`Product not found for slug: '${productSlug}' (Search term: '${productSearchTerm}')`, error?.message);
    // Return a 404 error but still provide basic HTML tags
    // This helps debug, as we know the function ran but failed to find data.
    const html404 = `
      <!DOCTYPE html><html><head><title>Product Not Found</title>
      <meta property="og:title" content="Product Not Found" />
      <meta property="og:description" content="The requested product could not be found with slug: ${productSlug}" />
      </head><body>Product not found. Searched for: ${productSearchTerm}</body></html>`;
      
    return new Response(html404, {
      status: 404,
      headers: { ...corsHeaders, "Content-Type": "text/html" },
    });
  }

  // --- Prepare data for HTML tags ---
  const title = productData["Product Title"] ?? "Dagina Designs";
  const description = productData["Description"] ?? "Beautiful jewelry from Dagina Designs.";
  const imageUrl = productData["Image"] ?? "https://cxnkagfbymztpwszfaiw.supabase.co/storage/v1/object/public/product-images/Crystal%20Quill%20Gold%20&%20Diamond%20Hoops%20&%20Huggies%20Earring.jpg"; // Fallback image
  const pageUrl = url.href; // The full URL that was visited

  // --- This is the HTML <head> with the new OG tags ---
  const htmlContent = `
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-TABLE">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      
      <title>${title}</title>
      <meta property="og:title" content="${title}" />
      <meta property="og:description" content="${description}" />
      <meta property="og:image" content="${imageUrl}" />
      <meta property="og:url" content="${pageUrl}" />
      <meta property="og:type" content="product" />
      <meta property="og:site_name" content="Dagina Designs" />
      
      <meta name="twitter:card" content="summary_large_image">
      <meta name="twitter:title" content="${title}">
      <meta name="twitter:description" content="${description}">
      <meta name="twitter:image" content="${imageUrl}">
      <style>
        @import url('https://fonts.googleapis.com/css2?family=Playfair+Display:wght@700&family=Lato:wght@400;700&display=swap');
        body { font-family: 'Lato', sans-serif; margin: 0; padding: 20px; display: flex; justify-content: center; align-items: center; background-color: #f9f9f9; color: #333; min-height: 100vh; }
        .container { max-width: 600px; text-align: center; }
        img { width: 100%; max-width: 400px; height: auto; border-radius: 16px; box-shadow: 0 8px 24px rgba(0,0,0,0.1); margin-bottom: 24px; }
        h1 { font-family: 'Playfair Display', serif; font-size: 2.25rem; color: #1a1a1a; margin-bottom: 16px; }
        p { font-size: 1.1rem; color: #555; line-height: 1.6; margin-bottom: 32px; }
        .cta-text { font-size: 1rem; color: #333; font-weight: bold; }
        .actions { margin-top: 24px; display: flex; flex-direction: column; gap: 16px; width: 100%; max-width: 350px; margin-left: auto; margin-right: auto; }
        .actions a { display: block; padding: 16px 24px; background-color: #B69121; color: white; text-decoration: none; border-radius: 30px; font-weight: bold; font-size: 1rem; transition: transform 0.2s ease; }
        .actions a:hover { transform: translateY(-2px); }
        .actions a.secondary { background-color: #ffffff; color: #B69121; border: 2px solid #B69121; }
      </style>
    </head>
    <body>
      <div class="container">
        <img src="${imageUrl}" alt="${title}">
        <h1>${title}</h1>
        <p>${description}</p>
        <p class="cta-text">Loading Dagina Designs...</p>
        
        <script>
          // Try to redirect to the app's internal route
          window.location.replace("https://www.dagina.design/product/${productSlug}");
        </script>
        
        <div class="actions">
          <a href="https://www.dagina.design/product/${productSlug}">View in App</a>
          <a href="https://www.dagina.design" class="secondary">Back to Home</a>
        </div>
      </div>
    </body>
    </html>
  `;

  return new Response(htmlContent, {
    headers: { ...corsHeaders, "Content-Type": "text/html" },
  });
});