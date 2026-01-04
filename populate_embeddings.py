import os
import requests
import time
from io import BytesIO
from PIL import Image
from supabase import create_client, Client
from sentence_transformers import SentenceTransformer
from dotenv import load_dotenv
load_dotenv()
# --- CONFIGURATION ---
# ⚠️ CRITICAL: Match this to your database column size!
# If you ran the 'vector(768)' migration -> use 'clip-ViT-L-14'
# If you are still on 'vector(512)'      -> use 'clip-ViT-B-32'
MODEL_NAME = 'openai/clip-vit-base-patch32' 

# Supabase Settings
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

print(f"🔄 Initializing...")
print(f"   Model: {MODEL_NAME}")
print(f"   Target URL: {SUPABASE_URL}")

# Load resources
try:
    model = SentenceTransformer(MODEL_NAME)
    print("✅ Model loaded successfully.")
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
    print("✅ Supabase client connected.")
except Exception as e:
    print(f"❌ Setup Error: {e}")
    exit(1)

def generate_embedding(url):
    """Downloads image and generates vector. Returns List[float] or None."""
    try:
        # print(f"      ⬇️ Downloading: {url[:50]}...") 
        resp = requests.get(url, timeout=10)
        resp.raise_for_status()
        
        image_bytes = BytesIO(resp.content)
        img = Image.open(image_bytes)
        
        # Simple validation
        if img.mode != 'RGB':
            img = img.convert('RGB')
            
        vector = model.encode(img).tolist()
        return vector
    except Exception as e:
        print(f"      ❌ Image Error: {e}")
        return None

def process_table(table_name):
    print(f"\n========================================")
    print(f"🚀 PROCESSING TABLE: {table_name}")
    print(f"========================================")
    
    total_processed = 0
    total_errors = 0
    
    while True:
        # Fetch 50 items that don't have an embedding yet
        print(f"\n🔍 Fetching next batch of NULL embeddings...")
        
        try:
            response = supabase.table(table_name)\
                .select("id, Image")\
                .is_("embedding", "null")\
                .limit(50)\
                .execute()
            
            rows = response.data
        except Exception as e:
            print(f"❌ Database Fetch Error: {e}")
            break

        if not rows:
            print("✅ No more items with NULL embeddings found in this table.")
            break
            
        print(f"📦 Batch contains {len(rows)} items. Starting processing...\n")
        
        for i, row in enumerate(rows):
            record_id = row['id']
            img_data = row.get('Image')
            
            print(f"   [{i+1}/{len(rows)}] ID: {record_id}")

            # 1. Extract the first valid image URL
            image_url = None
            if isinstance(img_data, list) and len(img_data) > 0:
                image_url = img_data[0]
            elif isinstance(img_data, str):
                # Handle stringified arrays like '{"url1","url2"}'
                clean = img_data.strip('{}').replace('"', '')
                urls = clean.split(',')
                if len(urls) > 0 and urls[0]:
                    image_url = urls[0]

            if not image_url:
                print(f"      ⚠️ SKIP: No image URL found in column.")
                total_errors += 1
                continue

            print(f"      📸 Found Image: {image_url[:40]}...")

            # 2. Generate Embedding
            vector = generate_embedding(image_url)
            
            if vector:
                # 3. Update Database
                try:
                    supabase.table(table_name)\
                        .update({"embedding": vector})\
                        .eq("id", record_id)\
                        .execute()
                    print(f"      ✅ SAVED: Embedding updated in DB.")
                    total_processed += 1
                except Exception as db_err:
                    print(f"      ❌ SAVE FAILED: {db_err}")
                    total_errors += 1
            else:
                print(f"      ❌ SKIP: Could not generate embedding.")
                total_errors += 1
                
            # Optional: tiny sleep to be nice to the server
            # time.sleep(0.1) 

    print(f"\n🏁 Finished {table_name}.")
    print(f"   Total Processed: {total_processed}")
    print(f"   Total Skipped/Failed: {total_errors}")

if __name__ == "__main__":
    # 1. Process Products
    # process_table("products")
    
    # 2. Process Designer Products
    process_table("designerproducts")
    
    print("\n🎉 ALL TABLES COMPLETE.")