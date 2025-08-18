import os
from fastapi import FastAPI
from pydantic import BaseModel
from sentence_transformers import SentenceTransformer

EMBED_MODEL = os.getenv("EMBED_MODEL","sentence-transformers/all-MiniLM-L12-v2")
model = SentenceTransformer(EMBED_MODEL)
app = FastAPI()

class EmbedReq(BaseModel):
    texts: list[str]

@app.get("/healthz")
def health():
    return {"ok":True, "model":EMBED_MODEL}

@app.post("/embed")
def embed(r: EmbedReq):
    embs = model.encode(r.texts, convert_to_numpy=True).tolist()
    return {"embeddings": embs, "dim": len(embs[0]) if embs else 0}
