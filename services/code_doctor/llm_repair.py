import os, json, httpx
from typing import List, Dict, Any

OPENAI_KEY = os.getenv("OPENAI_API_KEY")
OPENAI_BASE = os.getenv("OPENAI_API_BASE","https://api.openai.com/v1")
OPENAI_MODEL = os.getenv("OPENAI_MODEL","gpt-4o-mini")

LOW_RISK_TYPES={"missing_symbol","missing_attribute","signature_mismatch"}

def llm_repair_if_needed(code:str, language:str, issues:List[Dict[str,Any]], enable:bool=True):
    if not enable or not OPENAI_KEY:
        return code, []
    # decide if any high risk (logic) issue present
    high = any(i["type"] not in LOW_RISK_TYPES for i in issues)
    if not high:
        return code, []
    prompt = f"""You are a senior {language} engineer. Given code and issues, produce a corrected version.
Must preserve licensing headers. Only return corrected code, no commentary.
Issues: {json.dumps(issues)}
CODE:
```{language}
{code}
```"""
    try:
        r = httpx.post(f"{OPENAI_BASE}/chat/completions",
                       headers={"Authorization":f"Bearer {OPENAI_KEY}"},
                       json={"model":OPENAI_MODEL,
                             "messages":[{"role":"user","content":prompt}],
                             "temperature":0.0,
                             "max_tokens": 1200},
                       timeout=30.0)
        if r.status_code>=300:
            return code, []
        corrected = r.json()["choices"][0]["message"]["content"]
        # strip fences if present
        if "```" in corrected:
            segs=corrected.split("```")
            # find longest code segment
            longest=""
            for s in segs:
                if len(s)>len(longest) and not s.strip().startswith("json"):
                    longest=s
            corrected=longest.strip()
        actions=["llm_repair"]
        return corrected, actions
    except Exception:
        return code, []
