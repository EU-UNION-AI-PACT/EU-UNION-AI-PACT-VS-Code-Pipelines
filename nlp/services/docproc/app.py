import os, uuid, hashlib, json, re, datetime
from fastapi import FastAPI, UploadFile, HTTPException, Depends
from pydantic import BaseModel
import psycopg2, psycopg2.extras
import requests

DB_HOST = os.getenv("DB_HOST","pg")
DB_PORT = int(os.getenv("DB_PORT","5432"))
DB_USER = os.getenv("DB_USER","nlp")
DB_PASS = os.getenv("DB_PASS","nlp")
DB_NAME = os.getenv("DB_NAME","nlpdb")
EMBED_URL = os.getenv("EMBEDDING_URL")
LEDGER_DIR = os.getenv("LEDGER_DIR","/data/ledger")
HASH_ALGO = os.getenv("HASH_ALGO","sha256")
CLASS_FILE = os.getenv("CLASSIFICATION_FILE")
POLICY_ENDPOINT = os.getenv("POLICY_ENDPOINT")
DEFAULT_CLASS = os.getenv("DEFAULT_CLASSIFICATION","internal")

os.makedirs(LEDGER_DIR, exist_ok=True)

with open(CLASS_FILE,'r',encoding='utf-8') as f:
    classification_rules = f.read()

import yaml
cls_conf = yaml.safe_load(classification_rules)

app = FastAPI()

def db():
    return psycopg2.connect(
        host=DB_HOST, port=DB_PORT, user=DB_USER,
        password=DB_PASS, dbname=DB_NAME
    )

def classify_text(txt:str)->str:
    for lvl in cls_conf.get("rules",{}).get("patterns",{}):
        patterns = cls_conf["rules"]["patterns"][lvl]
        for p in patterns:
            if re.search(p, txt):
                return lvl
    return cls_conf.get("default", DEFAULT_CLASS)

def hash_bytes(data:bytes)->str:
    h = hashlib.new(HASH_ALGO)
    h.update(data)
    return h.hexdigest()

def call_policy(action:str, classification:str, user_roles):
    try:
        r = requests.post(POLICY_ENDPOINT, json={"input":{
            "action":action,
            "classification":classification,
            "user_roles":user_roles
        }}, timeout=3)
        if r.status_code == 200:
            decision = r.json()
            if decision.get("result",False):
                return True, None
            # check deny messages:
            if "deny_export" in decision.get("result",{}):
                return False, decision["result"]["deny_export"]
        return False, "Policy denied"
    except Exception as e:
        return False, f"Policy error: {e}"

class IngestResponse(BaseModel):
    doc_id: str
    classification: str
    hash_hex: str

@app.get("/healthz")
def health():
    return {"ok":True}

@app.post("/ingest", response_model=IngestResponse)
async def ingest(file: UploadFile, roles: str = "data-steward"):
    data = await file.read()
    cls = classify_text(data.decode(errors="ignore"))
    allowed, reason = call_policy("ingest", cls, roles.split(","))
    if not allowed:
        raise HTTPException(403, f"Ingest blockiert: {reason}")
    doc_id = str(uuid.uuid4())
    hash_hex = hash_bytes(data)
    fingerprint = hash_hex[:32]  # simplifiziert; könnte man semantisch erweitern
    conn = db()
    cur = conn.cursor()
    cur.execute("INSERT INTO documents (id,title,classification,hash_hex,original_path,raw_bytes,fingerprint) VALUES (%s,%s,%s,%s,%s,%s,%s)",
                (doc_id, file.filename, cls, hash_hex, file.filename, psycopg2.Binary(data), fingerprint))
    conn.commit()
    cur.close(); conn.close()
    # Chunken + Embedding
    text = data.decode(errors="ignore")
    chunks = [text[i:i+1500] for i in range(0,len(text),1500)]
    for idx, chunk in enumerate(chunks):
        er = requests.post(EMBED_URL, json={"texts":[chunk]}).json()
        vec = er["embeddings"][0]
        conn = db()
        cur = conn.cursor()
        cur.execute("INSERT INTO embeddings (doc_id, chunk_index, content, embedding) VALUES (%s,%s,%s,%s)",
                    (doc_id, idx, chunk, vec))
        conn.commit()
        cur.close(); conn.close()
    # Ledger Append
    ledger_entry = {
        "ts": datetime.datetime.utcnow().isoformat()+"Z",
        "doc_id": doc_id,
        "filename": file.filename,
        "hash": hash_hex,
        "classification": cls,
        "fingerprint": fingerprint
    }
    with open(os.path.join(LEDGER_DIR,"ledger.jsonl"),"a",encoding="utf-8") as lf:
        lf.write(json.dumps(ledger_entry)+"\n")
    return IngestResponse(doc_id=doc_id, classification=cls, hash_hex=hash_hex)
