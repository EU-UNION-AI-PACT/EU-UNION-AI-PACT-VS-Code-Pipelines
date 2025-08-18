import os, hashlib, json, requests
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from pathlib import Path

LEDGER_DIR = Path(os.getenv("LEDGER_DIR","/data/ledger"))
HASH_ALGO = os.getenv("HASH_ALGO","sha256")
WIPO_UA = os.getenv("WIPO_USER_AGENT","Local-IP-Client")
EPO_API_KEY = os.getenv("EPO_API_KEY")
EPO_API_SECRET = os.getenv("EPO_API_SECRET")

app = FastAPI()

@app.get("/healthz")
def health():
    return {"ok":True,"ledger_exists": LEDGER_DIR.exists()}

class VerifyReq(BaseModel):
    hash_hex: str

@app.post("/verify")
def verify(req: VerifyReq):
    ledger_file = LEDGER_DIR / "ledger.jsonl"
    if not ledger_file.exists():
        raise HTTPException(404,"Ledger nicht gefunden")
    for line in ledger_file.open("r",encoding="utf-8"):
        js = json.loads(line)
        if js.get("hash")==req.hash_hex:
            return {"present": True, "entry": js}
    return {"present": False}

@app.get("/wipo/prior_art")
def wipo_prior_art(q:str):
    # Einfacher OpenSearch Query (Beispiel - Terms anpassen)
    endpoint = f"https://patentscope.wipo.int/search/en/search.jsf"  # UI; API: opensearch oft beschränkt
    # Hinweis: Echte API / Bulk-Download eingeschränkt. Platzhalter:
    return {"note":"Für echte WIPO programmatische Suche API Terms & Conditions prüfen.","query":q}

@app.get("/epo/ops/query")
def epo_ops(q:str="artificial intelligence"):
    if not (EPO_API_KEY and EPO_API_SECRET):
        return {"error":"Kein EPO Key gesetzt"}
    # Placeholder call (OPS echte Endpoints: /rest-services/published-data/search)
    # Hier NICHT real request (Rate / Auth), nur strukturelles Beispiel:
    return {
        "note":"EPO OPS REST echte Anfrage hier implementieren (OAuth2 Basic + Accept Header).",
        "query": q
    }
