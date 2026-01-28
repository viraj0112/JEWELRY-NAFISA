import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

// Get environment variables
const SERVICE_ACCOUNT_KEY = Deno.env.get("GCP_SERVICE_ACCOUNT_KEY");
const SHEET_ID = Deno.env.get("GOOGLE_SHEET_ID");
const SHEET_RANGE = Deno.env.get("GOOGLE_SHEET_RANGE");

console.log("✅ Sync-to-sheets (Deno-native) function starting...");

// Helper to get Google OAuth2 access token
async function getAccessToken(): Promise<string> {
  if (!SERVICE_ACCOUNT_KEY)
    throw new Error("Missing GCP_SERVICE_ACCOUNT_KEY secret");
  const credentials = JSON.parse(SERVICE_ACCOUNT_KEY);
  const now = Math.floor(Date.now() / 1000);

  const jwtHeader = btoa(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const jwtClaim = btoa(
    JSON.stringify({
      iss: credentials.client_email,
      scope: "https://www.googleapis.com/auth/spreadsheets",
      aud: "https://oauth2.googleapis.com/token",
      exp: now + 3600,
      iat: now,
    })
  );
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "pkcs8",
    Uint8Array.from(
      atob(credentials.private_key.split("-----")[2].replace(/\n/g, "")),
      (c) => c.charCodeAt(0)
    ),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const sigBuffer = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    encoder.encode(`${jwtHeader}.${jwtClaim}`)
  );
  const jwtSignature = btoa(String.fromCharCode(...new Uint8Array(sigBuffer)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
  const jwt = `${jwtHeader}.${jwtClaim}.${jwtSignature}`;

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const tokenJson = await tokenRes.json();
  if (!tokenJson.access_token) throw new Error("Failed to obtain access token");
  return tokenJson.access_token;
}

// Utility for array-like fields
function formatArray(arr: string[] | null | undefined): string {
  if (!arr || arr.length === 0) return "";
  return arr.map((i) => String(i)).join(", ");
}

serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ message: "Only POST allowed" }), {
        status: 405,
      });
    }

    const payload = await req.json();
    if (!payload?.record)
      throw new Error("Invalid webhook payload: missing record");

    const newRecord = payload.record;

    const rowData = [
      newRecord.id || "",           // Matches Column A (id)
      newRecord.created_at || "",   // Matches Column B (created_at)
      newRecord.user_id || "",      // Matches Column C (user_id)
      newRecord.user_name || "",    // Matches Column D (user_name)
      newRecord.user_email || "",   // Matches Column E (user_email)
      newRecord.user_phone || "", 
      newRecord.product_id || "",
      newRecord.product_table || "",  // Matches Column F (user_phone),
      newRecord.product_title || "", // Matches Column G (product_title)
      newRecord.additional_notes || "", // Matches Column H (additional_notes)
      newRecord.metal_purity || "", // Matches Column I (metal_purity)
      newRecord.gold_weight || "", // Matches Column J (gold_weight)
      newRecord.metal_color || "", // Matches Column K (metal_color)
      newRecord.metal_finish || "",
      newRecord.metal_type || "",      // Y: product_url
      formatArray(newRecord.stone_type),
      formatArray(newRecord.stone_color),
      formatArray(newRecord.stone_count),
      formatArray(newRecord.stone_purity),
      formatArray(newRecord.stone_cut),
      formatArray(newRecord.stone_used),
      formatArray(newRecord.stone_weight),
      formatArray(newRecord.stone_setting),
      newRecord.additional_notes || "", // W: additional_notes
      newRecord.phone_number || "",     // X: phone_number (Again? Or is F user_phone and X phone_number?)
      newRecord.product_url || "" 
    ];

    console.log("📤 Sending to Google Sheets...");
    const accessToken = await getAccessToken();

    const res = await fetch(
      `https://sheets.googleapis.com/v4/spreadsheets/${SHEET_ID}/values/${SHEET_RANGE}:append?valueInputOption=USER_ENTERED`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ values: [rowData] }),
      }
    );

    const result = await res.json();
    console.log("✅ Sheets API response:", result);

    return new Response(JSON.stringify({ status: "ok", result }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("❌ Error syncing to sheets:", message);

    return new Response(JSON.stringify({ error: message || "Unknown error" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});

console.log("🚀 Sync-to-sheets function deployed successfully");
