import os
import requests
from supabase import Client, create_client
from sentence_transformers import SentenceTransformer
from dotenv import load_dotenv
from PIL import Image
from io import BytesIO

load_dotenv()
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
print(SUPABASE_URL)
print(SUPABASE_SERVICE_ROLE_KEY)

try:
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
except Exception as e:
    print(f"Error initializing Supabase client: {e}")
    exit()

try:
    print("Loading the model...")
    model = SentenceTransformer(os.getenv("MODEL_NAME"))
    print("model loaded.")
except Exception as e:
    print(f"Error loading model due to following exception: {e}")
    exit()

def process_table(table_name, image_column):
    '''Function to process table and image column.'''
    try:
        response = supabase.table(table_name).select(f'id, "{image_column}"').is_('embedding', 'NULL').execute()
        items = response.data
    except Exception as e:
        print(f"Error fetching table name {table_name} due to following exception.: {e}")
        return

    if not items:
        print(f"No items found in {table_name} needing embeddings.")
        return
    print(f"Found {len(items)} items to process in {table_name}...")

    for i in items:
        item_id = i['id']
        image_url = i[image_column]

        if not image_url:
            print(f"Skipping {table_name} item {item_id} (no image URL)")
            continue

        try:
            headers = {
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36",
                }
            img_response = requests.get(image_url, headers = headers, stream=True, timeout=10)

            if img_response.status_code != 200:
                print(f"Failed to download image for {table_name} {item_id} (Status: {img_response.status_code})")
                continue
            img = Image.open(BytesIO(img_response.content))

            embedding = model.encode(img)
            embedding_list = embedding.tolist()

            supabase.table(table_name).update({
                'embedding': embedding_list
            }).eq('id', item_id).execute()

            print(f"Successfully processed {table_name} item {item_id}")
        except Exception as e:
            print(f"--- ERROR processing {table_name} {item_id}: {e} ---")

process_table('products', 'Image')
process_table('designerproducts', 'Image')
process_table('pins', 'image_url')

print("\nAll embedding backfills complete.")

