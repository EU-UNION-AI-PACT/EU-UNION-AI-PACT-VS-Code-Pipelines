import os, json, pathlib, time, hashlib

LEDGER_DIR=pathlib.Path(os.getenv("CODE_DOCTOR_LEDGER","./code-doctor-ledger"))
LEDGER_DIR.mkdir(parents=True, exist_ok=True)
LOG=LEDGER_DIR / "transformations.jsonl"

def record_transformation(payload:dict)->bool:
    try:
        payload["ts"]=time.time()
        payload["entry_hash"]=hashlib.sha256(json.dumps(payload,sort_keys=True).encode()).hexdigest()
        with open(LOG,"a",encoding="utf-8") as f:
            f.write(json.dumps(payload)+"\n")
        return True
    except Exception:
        return False
