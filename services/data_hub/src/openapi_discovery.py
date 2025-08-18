from __future__ import annotations
import os, httpx, re
from typing import List, Dict, Any
import urllib.parse as up

ALLOWED = set([h.strip() for h in os.getenv("ALLOWED_OPENAPI_HOSTS","").split(",") if h.strip()])
TIMEOUT = int(os.getenv("OPENAPI_FETCH_TIMEOUT","20"))

def host_allowed(url:str)->bool:
    try:
        netloc=up.urlparse(url).netloc
        return any(netloc.endswith(a) for a in ALLOWED) if ALLOWED else True
    except Exception:
        return False

async def fetch_openapi(url:str)->dict|None:
    """Fetch OpenAPI spec from URL"""
    if not host_allowed(url):
        return None
    try:
        async with httpx.AsyncClient(timeout=TIMEOUT) as client:
            r=await client.get(url)
            r.raise_for_status()
            js=r.json()
            if "paths" in js:
                return js
    except Exception as e:
        print(f"OpenAPI fetch error for {url}: {e}")
        return None
    return None

async def search_openapi_endpoints(q: str, limit:int=10)->List[Dict[str,Any]]:
    """Search OpenAPI endpoints for relevant operations"""
    # For demo: static small catalog; in real scenario you'd maintain registry
    candidates=[
        "https://httpbin.org/spec.json",
        # Add more as needed - these are examples
    ]
    
    # Add GitHub and Open-Meteo if allowed
    if any("api.github.com" in h for h in ALLOWED):
        candidates.append("https://api.github.com/spec.json")
    if any("api.open-meteo.com" in h for h in ALLOWED):
        candidates.append("https://api.open-meteo.com/v1/spec.json")
    
    out=[]
    q_l=q.lower()
    
    for c in candidates:
        spec=await fetch_openapi(c)
        if not spec: 
            continue
            
        for p, ops in list(spec.get("paths",{}).items())[:200]:
            if not isinstance(ops, dict):
                continue
                
            for method, opdef in ops.items():
                if not isinstance(opdef, dict):
                    continue
                    
                summary = opdef.get("summary","")
                description = opdef.get("description","")
                txt = (summary + " " + description).lower()
                
                # Simple text matching
                if q_l in txt or re.search(rf"\\b{re.escape(q_l)}\\b", txt):
                    out.append({
                        "source": c,
                        "kind": "api_operation",
                        "id": f"{c}:{method}:{p}",
                        "title": summary or f"{method.upper()} {p}",
                        "description": description,
                        "url": p,
                        "score": 0.0
                    })
                    
    return out[:limit]
