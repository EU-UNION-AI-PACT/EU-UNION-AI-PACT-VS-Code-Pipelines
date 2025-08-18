import os, json, hashlib, time, pathlib
from dataclasses import dataclass
from typing import List, Optional

LEDGER_DIR = pathlib.Path(os.getenv("LEDGER_DIR","./storage/ledger"))
BATCH_MAX = int(os.getenv("LEDGER_BATCH_MAX","500"))
CURRENT_BATCH_FILE = LEDGER_DIR / "current_batch.jsonl"
INDEX_FILE = LEDGER_DIR / "batches.index.jsonl"

LEDGER_DIR.mkdir(parents=True, exist_ok=True)

@dataclass
class Entry:
    ts: float
    kind: str
    payload: dict

def _hash_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def append_entry(kind: str, payload: dict):
    e = Entry(ts=time.time(), kind=kind, payload=payload)
    line = json.dumps(e.__dict__, sort_keys=True)
    with open(CURRENT_BATCH_FILE,"a", encoding="utf-8") as f:
        f.write(line+"\n")
    # rollover?
    if sum(1 for _ in open(CURRENT_BATCH_FILE,"r",encoding="utf-8")) >= BATCH_MAX:
        finalize_batch()

def finalize_batch():
    if not CURRENT_BATCH_FILE.exists():
        return
    lines = CURRENT_BATCH_FILE.read_text(encoding="utf-8").strip().splitlines()
    if not lines: return
    leaf_hashes: List[str] = []
    for ln in lines:
        leaf_hashes.append(_hash_bytes(ln.encode()))
    # Merkle Build
    layer = leaf_hashes[:]
    tree = [leaf_hashes]
    while len(layer) > 1:
        nxt=[]
        for i in range(0,len(layer),2):
            a=layer[i]
            b=layer[i+1] if i+1 < len(layer) else layer[i]
            nxt.append(_hash_bytes((a+b).encode()))
        tree.append(nxt)
        layer=nxt
    merkle_root = layer[0]
    batch_id = f"{int(time.time())}_{merkle_root[:16]}"
    batch_file = LEDGER_DIR / f"batch_{batch_id}.jsonl"
    CURRENT_BATCH_FILE.rename(batch_file)
    meta = {
        "batch_id": batch_id,
        "entries": len(lines),
        "merkle_root": merkle_root,
        "first_ts": json.loads(lines[0])["ts"],
        "last_ts": json.loads(lines[-1])["ts"]
    }
    with open(INDEX_FILE,"a",encoding="utf-8") as idx:
        idx.write(json.dumps(meta)+"\n")
    # (Optional) Sign root via Vault Transit / TSA trigger external script
    print(f"[ledger] Finalized batch {batch_id} entries={meta['entries']} root={merkle_root}")

def verify_batch(batch_id: str) -> bool:
    batch_path = LEDGER_DIR / f"batch_{batch_id}.jsonl"
    if not batch_path.exists():
        return False
    lines = batch_path.read_text(encoding="utf-8").splitlines()
    leaf_hashes = [_hash_bytes(ln.encode()) for ln in lines]
    layer = leaf_hashes[:]
    while len(layer) > 1:
        nxt=[]
        for i in range(0,len(layer),2):
            a=layer[i]
            b=layer[i+1] if i+1 < len(layer) else layer[i]
            nxt.append(_hash_bytes((a+b).encode()))
        layer=nxt
    recalculated_root = layer[0]
    # lookup expected
    for meta_line in open(INDEX_FILE,"r",encoding="utf-8"):
        js=json.loads(meta_line)
        if js["batch_id"]==batch_id:
            return js["merkle_root"] == recalculated_root
    return False
