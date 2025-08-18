from __future__ import annotations
import os, httpx, asyncio
from typing import Dict, Any

DATA_HUB_URL = os.getenv("DATA_HUB_URL","http://data-hub:8400")

async def open_data_search(q:str, limit:int=5):
    """Search open data sources (CKAN + SPARQL)"""
    try:
        async with httpx.AsyncClient(timeout=30) as client:
            r = await client.get(f"{DATA_HUB_URL}/search/unified", params={
                "q":q,
                "limit":limit,
                "include":"ckan,sparql"
            })
            r.raise_for_status()
            return r.json()
    except Exception as e:
        return {"error": str(e), "results": []}

async def open_api_search(q:str, limit:int=5):
    """Search OpenAPI endpoints"""
    try:
        async with httpx.AsyncClient(timeout=30) as client:
            r = await client.get(f"{DATA_HUB_URL}/search/unified", params={
                "q":q,
                "limit":limit,
                "include":"openapi"
            })
            r.raise_for_status()
            return r.json()
    except Exception as e:
        return {"error": str(e), "results": []}

async def sandbox_execute(language:str, code:str, input_data:str=None):
    """Execute code in sandbox"""
    try:
        async with httpx.AsyncClient(timeout=30) as client:
            r = await client.post(f"{DATA_HUB_URL}/sandbox/run", json={
                "language": language,
                "code": code,
                "input_data": input_data
            })
            r.raise_for_status()
            return r.json()
    except Exception as e:
        return {"error": str(e)}
