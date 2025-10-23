import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

serve(async (req) => {
  const url = new URL(req.url);
  const pathSegments = url.pathname.split("/");

  const productId = pathSegments.pop() || pathSegments.pop();
  if (!productId || productId === "product-page") {
    return new Response(
      JSON.stringify({ error: "Product ID missing in URL" }),
      {
        headers: { "Content-Type": "application/json" },
        status: 400,
      }
    );
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  let productData: any = null;
  let error: any = null;

  let { data: prodData, error: prodError } = await supabase
    .from("products")
    .select('"Product Title", "Description", "Image"')
    .eq("id", productId)
    .maybeSingle();

  if (prodData) {
    productData = prodData;
  } else {
    let { data: designerProdData, error: designerProdError } = await supabase
      .from("designerproducts")
      .select('"Product Title", "description", "image"')
      .eq("id", productId)
      .maybeSingle();

    if (designerProdData) {
      productData = {
        "Product Title": designerProdData["Product Title"],
        Description: designerProdData["description"],
        Image: designerProdData["image"],
      };
    } else {
      error = designerProdError || prodError || new Error("Product not found");
    }
  }

  if (error || !productData) {
    console.error("Error fetching product:", error?.message);
    return new Response("Product not found", {
      status: 404,
      headers: { "Content-Type": "text/html" },
    });
  }

  const title = productData["Product Title"] ?? "Jewelry Product";
  const description = productData["Description"] ?? "Beautiful jewelry design.";
  const imageUrl = productData["Image"] ?? "https://via.placeholder.com/300";
  const htmlContent = `
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      
      <meta property="og:title" content="${title}" />
      <meta property="og:description" content="${description}" />
      <meta property="og:image" content="${imageUrl}" />
      <meta property="og:url" content="${url.href}" />
      <meta property="og:type" content="product" />
      
      <title>${title}</title>
      
      <style>
        @import url('https://fonts.googleapis.com/css2?family=Playfair+Display:wght@700&family=Lato:wght@400;700&display=swap');

        body { 
          font-family: 'Lato', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; 
          margin: 0; 
          padding: 0; 
          display: flex; 
          flex-direction: column; 
          align-items: center; 
          background-color: #ffffff; 
          color: #333;
        }
        .container {
          width: 100%;
          max-width: 600px;
          margin: 0 auto;
          padding: 20px;
          box-sizing: border-box;
          text-align: center;
        }
        img { 
          width: 100%; 
          max-width: 100%; /* Fill container width */
          height: auto; 
          margin-bottom: 24px; 
          border-radius: 16px; 
          box-shadow: 0 8px 24px rgba(0,0,0,0.1); 
        }
        h1 { 
          font-family: 'Playfair Display', serif;
          font-size: 2.25rem; /* 36px */
          color: #1a1a1a; 
          margin-bottom: 16px;
        }
        p { 
          font-size: 1.1rem; /* 18px */
          color: #555; 
          line-height: 1.6;
          margin-bottom: 32px;
        }
        .cta-text {
          font-size: 1rem;
          color: #333;
          font-weight: bold;
        }
        .actions { 
          margin-top: 24px; 
          display: flex;
          flex-direction: column;
          gap: 16px;
          width: 100%;
          max-width: 350px;
          margin-left: auto;
          margin-right: auto;
        }
        .actions a { 
          display: block; 
          padding: 16px 24px; 
          background-color: #B69121; /* Your app's theme color */
          color: white; 
          text-decoration: none; 
          border-radius: 30px; /* Fully rounded pills */
          font-weight: bold;
          font-size: 1rem; /* 16px */
          transition: transform 0.2s ease, box-shadow 0.2s ease;
          box-shadow: 0 4px 12px rgba(0,0,0,0.1);
        }
        .actions a:hover {
          transform: translateY(-2px);
          box-shadow: 0 6px 16px rgba(0,0,0,0.15);
        }
        /* Style for the "secondary" button */
        .actions a.secondary {
          background-color: #ffffff;
          color: #B69121;
          border: 2px solid #B69121;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <img src="${imageUrl}" alt="${title}">
        <h1>${title}</h1>
        <p>${description}</p>
        <p class="cta-text">Sign in or create an account to see full details.</p>
        
        <div class="actions">
          <a href="https://www.dagina.design/signup">Sign Up</a>
          <a href="https://www.dagina.design/login" class="secondary">Sign In</a>
        </div>
      </div>
    </body>
    </html>
  `;

  return new Response(htmlContent, {
    headers: { "Content-Type": "text/html" },
  });
});
