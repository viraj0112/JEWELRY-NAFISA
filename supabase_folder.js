

import "https://deno.land/std@0.224.0/dotenv/load.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { writeCSV } from "https://deno.land/x/csv@v0.9.2/mod.ts";

Deno.env.("SUPABASE_SERVICE_ROLE")

// Rings Engagement
// Rings Gemstones
// Rings Gesmtones
// Rings Infinity
// Rings Ruby
// Rings Silver
// Rings Solitaire
// Rings-Diamond

// import "https://deno.land/std@0.224.0/dotenv/load.ts";
// import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// const BUCKET_NAME = "product-images";

// const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

// async function debugList() {
//   console.log("🔍 Listing root of bucket...");
//   const root = await supabase.storage.from(BUCKET_NAME).list("", { limit: 100 });
//   console.log("Root contents:", root.data?.map(f => f.name));

//   console.log("\n🔍 Listing inside 'EnamelBangles'...");
//   const folder = await supabase.storage.from(BUCKET_NAME).list("EnamelBangles", { limit: 100 });
//   console.log("EnamelBangles contents:", folder.data?.map(f => f.name));

//   console.log("\nAny errors?");
//   console.log("Root error:", root.error);
//   console.log("Folder error:", folder.error);
// }

// await debugList();


// Initialize Supabase client
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

async function extractImageLinks() {
  console.log(`📂 Fetching images from '${FOLDER_NAME}' folder...`);

  const { data, error } = await supabase.storage
    .from(BUCKET_NAME)
    .list(FOLDER_NAME, { limit: 1000 });

  if (error) {
    console.error("❌ Error listing files:", error);
    return;
  }

  if (!data || data.length === 0) {
    console.warn(`⚠️ No files found in '${FOLDER_NAME}'`);
    return;
  }

  const records = [];
  for (const file of data) {
    const publicUrl = `${SUPABASE_URL}/storage/v1/object/public/${BUCKET_NAME}/${FOLDER_NAME}/${file.name}`;
    records.push({ filename: file.name, url: publicUrl });
  }

  // Write CSV file
  const csvArray = [["filename", "url"], ...records.map(r => [r.filename, r.url])];
  const csvData = csvArray.map(row => row.join(",")).join("\n");
  await Deno.writeTextFile(OUTPUT_FILE, csvData);

  console.log(`✅ Extracted ${records.length} image URLs`);
  console.log(`📁 Saved to ${OUTPUT_FILE}`);
}

await extractImageLinks();
