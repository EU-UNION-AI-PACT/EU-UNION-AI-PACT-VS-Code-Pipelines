from __future__ import annotations
import os, time, hashlib, json, asyncio
from typing import List, Dict, Any
from fastapi import FastAPI, HTTPException, Query, Body
from pydantic import BaseModel
import httpx
from cachetools import TTLCache
from .ckan import search_ckan_multi
from .sparql import search_wikidata
from .openapi_discovery import search_openapi_endpoints
from .embedding import get_embedder
from .fusion import fuse_results
from .sandbox import sandbox_execute
from .utils import log, hash_query

app = FastAPI(title="Data Hub", version="0.1.0")

CACHE_TTL = int(os.getenv("CACHE_TTL","3600"))
_result_cache = TTLCache(maxsize=512, ttl=CACHE_TTL)

class OpenDataResult(BaseModel):
    source: str
    kind: str
    id: str
    title: str
    description: str | None = None
    url: str | None = None
    score: float

class UnifiedSearchResponse(BaseModel):
    query: str
    total: int
    results: List[OpenDataResult]
    fused: bool
    sources: Dict[str,int]

@app.get("/healthz")
def health():
    return {"ok": True, "cache_size": len(_result_cache)}

@app.get("/search/unified", response_model=UnifiedSearchResponse)
async def unified(q: str = Query(..., min_length=2), limit: int = 10, include: str = "ckan,sparql,openapi"):
    key = f"unified::{q}::{limit}::{include}"
    if key in _result_cache:
        log.info("cache_hit", query_hash=hash_query(q))
        return _result_cache[key]
    
    parts = include.split(",")
    tasks=[]
    if "ckan" in parts:
        tasks.append(search_ckan_multi(q, limit=limit))
    if "sparql" in parts:
        tasks.append(search_wikidata(q, limit=limit))
    if "openapi" in parts:
        tasks.append(search_openapi_endpoints(q, limit=limit))
    
    if not tasks:
        raise HTTPException(400,"No sources requested")
    
    sub_results_lists = await asyncio.gather(*tasks, return_exceptions=True)
    collected=[]
    source_counts={}
    
    for res in sub_results_lists:
        if isinstance(res, Exception):
            log.warning("subsearch_error", error=str(res))
            continue
        collected.extend(res)
        for r in res:
            source_counts[r["source"]] = source_counts.get(r["source"],0)+1
    
    fused = fuse_results(q, collected, limit=limit)
    payload = UnifiedSearchResponse(
        query=q,
        total=len(fused),
        results=[OpenDataResult(**r) for r in fused],
        fused=True,
        sources=source_counts
    )
    _result_cache[key]=payload
    log.info("search_completed", query_hash=hash_query(q), total=len(fused), sources=list(source_counts.keys()))
    return payload

@app.get("/search/opendata")
async def search_opendata(q: str = Query(..., min_length=2), limit: int = 10):
    """CKAN + SPARQL only"""
    return await unified(q=q, limit=limit, include="ckan,sparql")

@app.get("/search/openapi")
async def search_openapi_only(q: str = Query(..., min_length=2), limit: int = 10):
    """OpenAPI endpoints only"""
    return await unified(q=q, limit=limit, include="openapi")

class SandboxReq(BaseModel):
    language: str = "python"
    code: str
    input_data: str | None = None

@app.post("/sandbox/run")
async def sandbox_run(req: SandboxReq):
    return await sandbox_execute(req.language, req.code, req.input_data)

@app.post("/ingest/external")
async def ingest_external(data: List[OpenDataResult]):
    """Optional: Materialisieren in RAG VectorStore"""
    emb = get_embedder()
    chunks=[]
    for d in data:
        text = (d.title or "") + "\n" + (d.description or "")
        chunks.append(text)
    
    if chunks:
        vectors = emb.embed(chunks)
        log.info("external_ingest", chunks=len(chunks), vectors=len(vectors))
    
    # Hier würdest du in deine bestehende RAG-Ingest-Pipeline schreiben.
    return {"ingested": len(chunks), "embedded": len(chunks)}

@app.post("/cache/flush")
def flush_cache():
    _result_cache.clear()
    return {"status":"flushed", "now": time.time()}

@app.get("/meta/sources")
def get_sources():
    """Verfügbare Datenquellen"""
    ckan_bases = [b.strip() for b in os.getenv("OPEN_DATA_CKAN_BASES","").split(",") if b.strip()]
    sparql_endpoint = os.getenv("SPARQL_ENDPOINT","https://query.wikidata.org/sparql")
    allowed_hosts = [h.strip() for h in os.getenv("ALLOWED_OPENAPI_HOSTS","").split(",") if h.strip()]
    
    return {
        "ckan_bases": ckan_bases,
        "sparql_endpoint": sparql_endpoint,
        "allowed_openapi_hosts": allowed_hosts,
        "cache_ttl": CACHE_TTL
    }
