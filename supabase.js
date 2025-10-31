import { createClient } from "@supabase/supabase-js";

// Initialize your Supabase client
const supabase = createClient(
  "https://cxnkagfbymztpwszfaiw.supabase.co",
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN4bmthZ2ZieW16dHB3c3pmYWl3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk4NDg3OTYsImV4cCI6MjA3NTQyNDc5Nn0.X7-tQBh-PwHEFoLr6BcRtbHcwnY-U4lFoHCnRd-EQjE"
);

/**
 * --- MODIFIED HELPER FUNCTION ---
 * Recursively lists files, handling pagination, and gets public URLs.
 * @param {string} bucketName - The name of the bucket.
 * @param {string} path - The current folder path to search.
 * @param {string[]} allUrls - An array to accumulate URLs.
 */
async function getUrlsRecursively(bucketName, path, allUrls) {
  const limit = 500; // Get up to 500 items per request
  let offset = 0;
  let allFileObjects = [];

  try {
    // 1. Loop to get all files, handling pagination
    while (true) {
      const { data: fileObjects, error: listError } = await supabase.storage
        .from(bucketName)
        .list(path, {
          limit: limit,
          offset: offset,
        });

      if (listError) {
        console.error(`Error listing files in '${path}' (offset ${offset}):`, listError.message);
        return; // Stop processing this folder on error
      }

      if (!fileObjects || fileObjects.length === 0) {
        break; // No more files in this directory, exit the loop
      }

      // Add the files from this "page" to our total list
      allFileObjects = allFileObjects.concat(fileObjects);

      // If we got fewer files than the limit, this was the last page
      if (fileObjects.length < limit) {
        break;
      }

      // Otherwise, increase the offset to get the next page
      offset += limit;
    }
  } catch (error) {
    console.error(`Error during pagination for path '${path}':`, error.message);
    return;
  }
  
  // 2. Process all items found in this directory
  for (const file of allFileObjects) {
    const fullPath = path ? `${path}/${file.name}` : file.name;

    if (file.id === null) {
      // This is a FOLDER (folders have 'id: null')
      // Call this function again to go one level deeper
      await getUrlsRecursively(bucketName, fullPath, allUrls);

    } else {
      // This is a FILE (files have an 'id')
      if (file.name !== ".emptyFolderPlaceholder") {
        // Get the public URL for the file's full path
        const { data: publicUrlData } = supabase.storage
          .from(bucketName)
          .getPublicUrl(fullPath);
        
        allUrls.push(publicUrlData.publicUrl);
      }
    }
  }
}

/**
 * Fetches public URLs for ALL files in a public bucket, including sub-folders.
 * @param {string} bucketName The name of your public bucket.
 */
async function getAllPublicImageUrls(bucketName) {
  const allUrls = []; // This array will store all found URLs
  console.log(`Starting scan of bucket: ${bucketName}...`);

  try {
    // Start the recursive scan from the root directory ('')
    await getUrlsRecursively(bucketName, '', allUrls);
    console.log(`Scan complete. Found ${allUrls.length} files.`);
    return allUrls;

  } catch (error) {
    console.error("An unexpected error occurred:", error.message);
    return [];
  }
}


// --- MAIN SCRIPT TO RUN AND SAVE TO CSV ---
(async () => {
  // Get all URLs using the new recursive function
  const imageUrls = await getAllPublicImageUrls("product-images");
  
  if (!imageUrls || imageUrls.length === 0) {
    console.log("No URLs found. CSV file will not be created.");
    return; // Exit if there's nothing to save
  }

  // 1. Format the data as a CSV string
  const header = "url\n"; // CSV header
  const rows = imageUrls.join("\n"); // Each URL on a new line
  const csvContent = header + rows;
  
  const fileName = "product_urls_all.csv";

  try {
    // 2. Write the string to a file using Deno's API
    await Deno.writeTextFile(fileName, csvContent);
    
    console.log(`✅ Successfully saved ${imageUrls.length} URLs to ${fileName}`);
  } catch (error) {
    console.error(`Error writing file: ${error.message}`);
  }
})();