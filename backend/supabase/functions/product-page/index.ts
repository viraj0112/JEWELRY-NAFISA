// Server-rendered share/preview page: emits Open Graph tags for a product so
// links unfurl in WhatsApp / iMessage / Slack, then bounces the visitor into
// the Flutter app.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeadersFor } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const APP_ORIGIN = "https://www.dagina.design";
const FALLBACK_IMAGE =
  "https://cxnkagfbymztpwszfaiw.supabase.co/storage/v1/object/public/product-images/Crystal%20Quill%20Gold%20&%20Diamond%20Hoops%20&%20Huggies%20Earring.jpg";

// ---------------------------------------------------------------------------
// Escaping.
//
// Everything below used to be interpolated raw. Two separate injection paths
// existed: product titles/descriptions are authored by designers (stored XSS,
// fires on every share-preview visit), and the slug comes straight off the URL
// (reflected XSS via a crafted link).
//
// Each sink needs its OWN escaping — HTML-escaping a value that lands in a
// <script> block does not make it safe, which is why there are three helpers.
// ---------------------------------------------------------------------------

/** HTML text and quoted-attribute contexts. */
function escapeHtml(value: unknown): string {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

/**
 * JavaScript string-literal context (inside `<script>`).
 *
 * JSON.stringify handles quotes and backslashes, but leaves `<` alone — so a
 * value containing `</script>` would still terminate the block early and start
 * fresh markup. Escaping `<` as < closes that.
 */
function toJsString(value: unknown): string {
  return JSON.stringify(String(value ?? "")).replaceAll("<", "\\u003c");
}

/**
 * URL used in an href/src. Rejects anything that isn't http(s) so a stored
 * `javascript:` or `data:` value can't become a clickable script trigger,
 * then HTML-escapes the result for the attribute it sits in.
 */
function safeUrlAttr(value: unknown, fallback: string): string {
  const raw = String(value ?? "").trim();
  try {
    const parsed = new URL(raw);
    if (parsed.protocol === "http:" || parsed.protocol === "https:") {
      return escapeHtml(parsed.toString());
    }
  } catch {
    // not an absolute URL — fall through
  }
  return escapeHtml(fallback);
}

serve(async (req) => {
  // Allowlisted per-request CORS; unknown origins get no
  // Access-Control-Allow-Origin and are blocked by the browser.
  const corsHeaders = corsHeadersFor(req);
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const url = new URL(req.url);
  const pathSegments = url.pathname.split("/");
  const productSlug = pathSegments.pop() || pathSegments.pop();

  if (!productSlug || productSlug === "product-page") {
    return new Response(
      JSON.stringify({ error: "Product slug missing in URL" }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      },
    );
  }

  // Rebuild a fuzzy search term from the slug:
  // "hearty-bliss-gemstone-pendant" -> "hearty%bliss%gemstone%pendant"
  const productSearchTerm = productSlug.replaceAll("-", "%");

  // Pre-escaped forms of the slug for the two sinks it reaches.
  const slugForHtml = escapeHtml(productSlug);
  const appProductUrl = `${APP_ORIGIN}/product/${
    encodeURIComponent(productSlug)
  }`;
  const appProductHref = escapeHtml(appProductUrl);

  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  let productData: Record<string, unknown> | null = null;
  let error: unknown = null;

  // --- Look the product up by title in both tables (case-insensitive) ---
  // .limit(1) rather than .maybeSingle(): the search term is a wildcard
  // pattern, so matching two or more products is ordinary, and maybeSingle()
  // throws in exactly that case.
  const { data: prodRows, error: prodError } = await supabase
    .from("products")
    .select('"Product Title", "Description", "Image", images_arr')
    .ilike('"Product Title"', productSearchTerm)
    .limit(1);

  if (prodRows && prodRows.length > 0) {
    productData = prodRows[0];
  } else {
    // NOTE: real columns are PascalCase ("Description", "Image"); an earlier
    // lowercase select never matched, so designerproducts OG tags always fell
    // through to the fallback below.
    const { data: designerRows, error: designerError } = await supabase
      .from("designerproducts")
      .select('"Product Title", "Description", "Image", images_arr')
      .ilike('"Product Title"', productSearchTerm)
      .limit(1);

    if (designerRows && designerRows.length > 0) {
      productData = designerRows[0];
    } else {
      error = designerError || prodError || new Error("Product not found");
    }
  }

  if (error || !productData) {
    console.error(
      `Product not found for slug: '${productSlug}' (search term: '${productSearchTerm}')`,
      error,
    );
    const html404 = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Product Not Found</title>
  <meta property="og:title" content="Product Not Found" />
  <meta property="og:description" content="The requested product could not be found." />
</head>
<body>Product not found: ${slugForHtml}</body>
</html>`;

    return new Response(html404, {
      status: 404,
      headers: { ...corsHeaders, "Content-Type": "text/html; charset=utf-8" },
    });
  }

  // --- Prepare values for the tags ---
  const title = escapeHtml(productData["Product Title"] ?? "Dagina Designs");
  const description = escapeHtml(
    productData["Description"] ?? "Beautiful jewelry from Dagina Designs.",
  );

  // "Image" is a text[] column, not a scalar; take the first element. Prefer
  // the unified images_arr (Phase 1) when present.
  const images = (productData["images_arr"] ?? productData["Image"]) as
    | string[]
    | null
    | undefined;
  const imageUrl = safeUrlAttr(images?.[0], FALLBACK_IMAGE);
  const pageUrl = safeUrlAttr(url.href, APP_ORIGIN);

  const htmlContent = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
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
      // Redirect into the app's internal route. The slug is emitted as a JSON
      // string literal, not pasted into the source, so a crafted slug cannot
      // break out of the quotes or close this script block.
      window.location.replace(${toJsString(appProductUrl)});
    </script>

    <div class="actions">
      <a href="${appProductHref}">View in App</a>
      <a href="${APP_ORIGIN}" class="secondary">Back to Home</a>
    </div>
  </div>
</body>
</html>`;

  return new Response(htmlContent, {
    headers: { ...corsHeaders, "Content-Type": "text/html; charset=utf-8" },
  });
});
