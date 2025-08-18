import json, pathlib, difflib
from typing import Dict

CANON_FILE = pathlib.Path("services/code_doctor/data/function_canon_map.json")

def load_canonical_map()->Dict[str,str]:
    if CANON_FILE.exists():
        return json.loads(CANON_FILE.read_text(encoding="utf-8"))
    return {}

def suggest_canonical(symbol:str, mapping:Dict[str,str]):
    if symbol in mapping:
        return mapping[symbol]
    # fuzzy
    candidates=list(mapping.keys())
    close=difflib.get_close_matches(symbol, candidates, n=1, cutoff=0.9)
    if close:
        return mapping[close[0]]
    return None
