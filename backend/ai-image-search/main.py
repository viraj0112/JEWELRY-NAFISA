import os
from fastapi import FastAPI, UploadFile, File, HTTPException
from supabase import create_client
import torch
from PIL import Image, UnidentifiedImageError
from io import BytesIO
from dotenv import load_dotenv
from fastapi.middleware.cors import CORSMiddleware
from sentence_transformers import SentenceTransformer
load_dotenv()

# -------- SUPABASE --------
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

# -------- CLIP --------
# 768-dim, to match the vector(768) embedding columns and match_products.
# Must be the exact same model + library as MODEL_NAME in
# scripts/populate_embeddings.py, or query and stored vectors aren't comparable.
MODEL_NAME = "clip-ViT-L-14"
device = "cuda" if torch.cuda.is_available() else "cpu"
print(f"Loading {MODEL_NAME} on {device}", flush=True)
model = SentenceTransformer(MODEL_NAME, device=device)

# Cosine similarity cut-off. Phone photos vs studio catalog shots rarely score
# above ~0.8 even for the same piece, so this starts permissive; tune via env.
MATCH_THRESHOLD = float(os.getenv("MATCH_THRESHOLD", "0.55"))
MATCH_COUNT = int(os.getenv("MATCH_COUNT", "20"))
MAX_FILE_SIZE = 5 * 1024 * 1024  # 5 MB

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
    return model.encode(image, normalize_embeddings=True).tolist()

@app.post("/search")
async def search_image(file: UploadFile = File(...)):
    size = 0
    content = bytearray()

    while True:
        chunk = await file.read(1024 * 1024)  # Read 1MB chunks
        if not chunk:
            break
        size += len(chunk)
        if size > MAX_FILE_SIZE:
            raise HTTPException(status_code=413, detail="File too large. Maximum size is 5MB.")
        content.extend(chunk)

    try:
        embedding = get_image_embedding(bytes(content))
    except UnidentifiedImageError:
        raise HTTPException(status_code=400, detail="Unsupported or corrupt image.")

    try:
        response = supabase.rpc(
            "match_products",
            {
                "query_embedding": embedding,
                "match_threshold": MATCH_THRESHOLD,
                "match_count": MATCH_COUNT,
            }
        ).execute()
    except Exception as e:
        # Don't disguise failures (e.g. a vector dimension mismatch) as
        # "no results" - that is what hid this service being broken.
        print(f"match_products failed: {e}", flush=True)
        raise HTTPException(status_code=502, detail=f"Search backend error: {e}")

    return response.data
