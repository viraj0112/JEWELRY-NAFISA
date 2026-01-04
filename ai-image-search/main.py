import os
from fastapi import FastAPI, UploadFile, File, HTTPException
from supabase import create_client
import torch
import clip
from PIL import Image
from io import BytesIO
from dotenv import load_dotenv
from fastapi.middleware.cors import CORSMiddleware
load_dotenv()

# -------- SUPABASE --------
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

# -------- CLIP --------
device = "cuda" if torch.cuda.is_available() else "cpu"
model, preprocess = clip.load("ViT-B/32", device=device)

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # restrict later
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def get_image_embedding(image_bytes):
    image = Image.open(BytesIO(image_bytes)).convert("RGB")
    image_input = preprocess(image).unsqueeze(0).to(device)

    with torch.no_grad():
        embedding = model.encode_image(image_input)

    embedding /= embedding.norm(dim=-1, keepdim=True)
    return embedding.cpu().numpy()[0].tolist()

@app.post("/search")
async def search_image(file: UploadFile = File(...)):
    # 10 MB limit
    MAX_FILE_SIZE = 10 * 1024 * 1024
    
    size = 0
    content = bytearray()
    
    while True:
        chunk = await file.read(1024 * 1024)  # Read 1MB chunks
        if not chunk:
            break
        size += len(chunk)
        if size > MAX_FILE_SIZE:
            raise HTTPException(status_code=413, detail="File too large. Maximum size is 10MB.")
        content.extend(chunk)
        
    image_bytes = bytes(content)
    embedding = get_image_embedding(image_bytes)
    
    try:
        # TEST CONNECTION
        test_response = supabase.table("products").select("id").limit(1).execute()

        print("--- DEBUG: Calling Supabase RPC 'match_products' ---", flush=True)
        response = supabase.rpc(
            "match_products",
            {
                "query_embedding": embedding,
                "match_threshold": 0.78,
                "match_count": 20,
            }
        ).execute()

        return response.data
    except Exception as e:
        return []
