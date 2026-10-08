import os
import requests
import time
import torch
from io import BytesIO
from PIL import Image
from supabase import create_client, Client
from sentence_transformers import SentenceTransformer
from dotenv import load_dotenv
load_dotenv()
# --- CONFIGURATION ---
# The DB is on vector(768). ai-image-search/main.py must use the same model
# (CLIP "ViT-L/14") or query and stored embeddings won't be comparable.
MODEL_NAME = 'clip-ViT-L-14'

# Supabase Settings
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

# Use the GPU when PyTorch was installed with CUDA support.
if torch.cuda.is_available():
    DEVICE = "cuda"
    DEVICE_LABEL = f"GPU ({torch.cuda.get_device_name(0)})"
else:
    DEVICE = "cpu"
    DEVICE_LABEL = "CPU"
    if "+cpu" in torch.__version__:
        DEVICE_LABEL += " — PyTorch is a CPU-only build, reinstall with CUDA to use the GPU"

print(f"🔄 Initializing...")
print(f"   Model: {MODEL_NAME}")
print(f"   Device: {DEVICE_LABEL}")
print(f"   Target URL: {SUPABASE_URL}")

# Load resources
try:
    model = SentenceTransformer(MODEL_NAME, device=DEVICE)
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
            
        vector = model.encode(img, normalize_embeddings=True).tolist()
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
    # Rows that failed stay NULL; remember them so they aren't refetched forever.
    failed_ids = set()

    while True:
        # Fetch 50 items that don't have an embedding yet
        print(f"\n🔍 Fetching next batch of NULL embeddings...")

        try:
            query = supabase.table(table_name)\
                .select("id, Images")\
                .is_("embedding", "null")
            if failed_ids:
                query = query.not_.in_("id", list(failed_ids))
            response = query.order("id").limit(50).execute()
            
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
            img_data = row.get('Images')
            
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
                failed_ids.add(record_id)
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
                    failed_ids.add(record_id)
                    total_errors += 1
            else:
                print(f"      ❌ SKIP: Could not generate embedding.")
                failed_ids.add(record_id)
                total_errors += 1
                
            # Optional: tiny sleep to be nice to the server
            # time.sleep(0.1) 

    print(f"\n🏁 Finished {table_name}.")
    print(f"   Total Processed: {total_processed}")
    print(f"   Total Skipped/Failed: {total_errors}")

if __name__ == "__main__":
    # 1. Process Products
    process_table("products")
    
    # 2. Process Designer Products
    process_table("designerproducts")

    # 3. Process Manufacturer Products
    process_table("manufacturerproducts")

    print("\n🎉 ALL TABLES COMPLETE.")