from __future__ import annotations
import os, httpx, asyncio
from typing import List, Dict, Any

CKAN_BASES = [b.strip() for b in os.getenv("OPEN_DATA_CKAN_BASES","").split(",") if b.strip()]

async def search_ckan(base: str, q: str, limit: int = 10) -> List[Dict[str,Any]]:
    """Search a single CKAN instance"""
    api = base
    if not api.endswith("/"):
        api+="/"
    if "package_search" not in api:
        # heuristic if root
        if api.endswith("/api/3"):
            api += "/action/package_search"
        elif api.endswith("/api/3/"):
            api += "action/package_search"
        elif "action/package_search" not in api:
            api += "api/3/action/package_search"
    
    params={"q": q, "rows": min(limit, 20)}
    
    try:
        async with httpx.AsyncClient(timeout=20) as client:
            r = await client.get(api, params=params)
            r.raise_for_status()
            js=r.json()
            res = js.get("result",{}).get("results",[])
            out=[]
            for rj in res:
                out.append({
                    "source": base,
                    "kind": "dataset",
                    "id": rj.get("id"),
                    "title": rj.get("title") or rj.get("name",""),
                    "description": rj.get("notes") or "",
                    "url": rj.get("url") or (rj.get("resources",[{}])[0].get("url") if rj.get("resources") else None),
                    "score": 0.0
                })
            return out
    except Exception as e:
        print(f"CKAN search error for {base}: {e}")
        return []

async def search_ckan_multi(q: str, limit:int=10)->List[Dict[str,Any]]:
    """Search across multiple CKAN instances"""
    tasks=[search_ckan(b, q, limit) for b in CKAN_BASES if b]
    if not tasks:
        return []
    
    res = await asyncio.gather(*tasks, return_exceptions=True)
    out=[]
    for r in res:
        if isinstance(r, list):
            out.extend(r)
    return out
