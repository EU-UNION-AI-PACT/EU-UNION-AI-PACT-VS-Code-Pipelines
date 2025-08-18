import yaml, pathlib
from typing import Dict, Any

RULE_DIR = pathlib.Path("services/code_doctor/ruleset")

def load_rulesets()->Dict[str,Any]:
    out={}
    if RULE_DIR.exists():
        for p in RULE_DIR.glob("*.yaml"):
            try:
                out[p.stem]=yaml.safe_load(p.read_text(encoding="utf-8"))
            except Exception:
                continue
    return out
