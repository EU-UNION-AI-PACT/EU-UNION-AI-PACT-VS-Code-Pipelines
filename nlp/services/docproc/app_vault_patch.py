# --- Patch Snippet: DB + Ledger Signing Integration ---
from vault_client import kv_get, transit_sign, transit_encrypt, db_dynamic_creds
import psycopg2, psycopg2.extras, os, hashlib, uuid, datetime, json, re, requests, yaml

VAULT_TRANSIT_KEY = os.getenv("VAULT_TRANSIT_KEY","ledger-sign")
VAULT_TRANSIT_ENCRYPT_KEY = os.getenv("VAULT_TRANSIT_ENCRYPT_KEY","doc-bytes")
USE_ENCRYPT=True  # Toggle

def db_conn():
    user, pwd = db_dynamic_creds()
    return psycopg2.connect(
        host=os.getenv("DB_HOST", "localhost"), 
        port=int(os.getenv("DB_PORT", "5432")), 
        user=user,
        password=pwd, 
        dbname=os.getenv("DB_NAME", "nlpdb")
    )

def hash_bytes(content: bytes) -> str:
    """Hash document bytes"""
    return hashlib.sha256(content).hexdigest()

def classify_text(text: str) -> str:
    """Simple text classification - replace with real logic"""
    if "confidential" in text.lower():
        return "confidential"
    return "internal"

def ingest_store(file_bytes:bytes, filename:str):
    hash_hex = hash_bytes(file_bytes)
    if USE_ENCRYPT:
        encrypted = transit_encrypt(VAULT_TRANSIT_ENCRYPT_KEY, file_bytes)
        raw_to_store = encrypted.encode()
    else:
        raw_to_store = file_bytes
    doc_id = str(uuid.uuid4())
    conn = db_conn(); cur = conn.cursor()
    cur.execute("""INSERT INTO documents (id,title,classification,hash_hex,original_path,raw_bytes,fingerprint)
                   VALUES (%s,%s,%s,%s,%s,%s,%s)""",
                (doc_id, filename, classify_text(file_bytes.decode(errors="ignore")), hash_hex,
                 filename, psycopg2.Binary(raw_to_store), hash_hex[:32]))
    conn.commit(); cur.close(); conn.close()
    return doc_id, hash_hex

def ledger_append(entry:dict):
    line = json.dumps(entry, ensure_ascii=False).encode()
    sig = transit_sign(VAULT_TRANSIT_KEY, line)
    entry["vault_signature"] = sig
    ledger_dir = os.getenv("LEDGER_DIR", "./storage/ledger")
    with open(os.path.join(ledger_dir,"ledger.jsonl"),"a",encoding="utf-8") as lf:
        lf.write(json.dumps(entry)+"\n")
