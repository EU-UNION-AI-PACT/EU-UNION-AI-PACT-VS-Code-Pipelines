import re
from typing import Dict, Any, List

ERROR_PATTERNS = [
    (r"NameError: name '(\w+)' is not defined", "missing_symbol"),
    (r"ReferenceError: (\w+) is not defined", "missing_symbol"),
    (r"AttributeError: '(\w+)' object has no attribute '(\w+)'", "missing_attribute"),
    (r"TypeError: (\w+)\(\) missing required positional argument", "signature_mismatch")
]

def classify_issue(error_log:str, lint_report:Dict[str,Any]|None)->List[Dict[str,Any]]:
    issues=[]
    if error_log:
        for pat,typ in ERROR_PATTERNS:
            for m in re.finditer(pat, error_log):
                symbol = m.group(1)
                issues.append({"type": typ, "symbol": symbol, "raw": m.group(0)})
    if lint_report:
        # Example: ESLint style array
        msgs = lint_report.get("messages") or lint_report.get("results") or []
        # Simplified; adapt for structure
        for item in msgs:
            rule = item.get("ruleId") or item.get("rule") or ""
            if "no-undef" in rule:
                issues.append({"type":"missing_symbol","symbol":item.get("message","").split("'")[1] if "'" in item.get("message","") else None,"raw":rule})
    # Deduplicate
    dedup={}
    out=[]
    for i in issues:
        key=(i["type"], i.get("symbol"))
        if key not in dedup:
            dedup[key]=1
            out.append(i)
    return out
