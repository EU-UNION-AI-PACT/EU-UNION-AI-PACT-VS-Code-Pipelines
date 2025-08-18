import os, requests
from fastapi import FastAPI, Header, HTTPException, Depends
from pydantic import BaseModel
DOCPROC = os.getenv("DOCPROC_URL","http://docproc:8100")
IPGUARD = os.getenv("IPGUARD_URL","http://ip-guard:8200")
TOKEN = os.getenv("INTERNAL_API_TOKEN","devtoken")

app = FastAPI()

@app.get("/healthz")
def h(): return {"ok":True}

def auth(x_auth_token:str=Header(None)):
    if x_auth_token!=TOKEN:
        raise HTTPException(401,"Unauthorized")

class ExportReq(BaseModel):
    doc_id: str

@app.get("/docs/{doc_id}/verify", dependencies=[Depends(auth)])
def verify(doc_id:str):
    # simple: doc hash lookup in ledger would need new endpoint: placeholder
    return {"doc_id":doc_id,"status":"NOT_IMPLEMENTED"}

@app.get("/prior-art/wipo")
def prior(q:str):
    r = requests.get(f"{IPGUARD}/wipo/prior_art", params={"q":q}, timeout=5)
    return r.json()
