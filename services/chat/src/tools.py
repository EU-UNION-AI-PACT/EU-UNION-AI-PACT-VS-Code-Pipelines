from __future__ import annotations
import time, os, json, httpx, asyncio
from typing import Dict, Any
from .tools_opendata import open_data_search, open_api_search, sandbox_execute

ENABLED = set(p.strip() for p in os.getenv("ENABLED_TOOLS","rag_search,prior_art,ledger_verify,open_data_search,open_api_search,sandbox_execute").split(","))

class ToolRegistry:
    def __init__(self):
        pass

    def is_enabled(self,name:str)->bool:
        return name in ENABLED

    def call_sync(self, name:str, params:Dict[str,Any])->Dict[str,Any]:
        """Synchronous wrapper of async tools (if needed)"""
        import asyncio
        loop = None
        try:
            loop = asyncio.get_event_loop()
        except RuntimeError:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
        
        return loop.run_until_complete(self.call(name, params))

    async def call(self, name:str, params:Dict[str,Any])->Dict[str,Any]:
        if name not in ENABLED:
            return {"error":"tool_disabled"}
            
        if name=="prior_art":
            return {"result":"(stub prior art search)","meta":{"kind":"prior_art"}}
            
        if name=="open_data_search":
            q=params.get("query","")
            limit=params.get("limit",5)
            res= await open_data_search(q, limit)
            return {"result":res,"meta":{"kind":"open_data"}}
            
        if name=="open_api_search":
            q=params.get("query","")
            limit=params.get("limit",5)
            res= await open_api_search(q, limit)
            return {"result":res,"meta":{"kind":"open_api"}}
            
        if name=="sandbox_execute":
            language=params.get("language","python")
            code=params.get("code","")
            input_data=params.get("input_data")
            res = await sandbox_execute(language, code, input_data)
            return {"result":res,"meta":{"kind":"sandbox"}}
            
        if name=="ledger_verify":
            return {"result":"stub ledger verify","meta":{"kind":"ledger"}}
            
        if name=="rag_search":
            # This would call your existing RAG search
            q=params.get("query","")
            return {"result":f"RAG results for: {q}","meta":{"kind":"rag"}}
            
        return {"error":"unknown_tool"}

    def get_available_tools(self)->list:
        """Return list of available tools"""
        return [
            {
                "name": "open_data_search",
                "description": "Search open data catalogs (CKAN, Wikidata)",
                "parameters": {"query": "str", "limit": "int"}
            },
            {
                "name": "open_api_search", 
                "description": "Search OpenAPI endpoints",
                "parameters": {"query": "str", "limit": "int"}
            },
            {
                "name": "sandbox_execute",
                "description": "Execute code in safe sandbox",
                "parameters": {"language": "str", "code": "str", "input_data": "str"}
            },
            {
                "name": "rag_search",
                "description": "Search local knowledge base",
                "parameters": {"query": "str"}
            }
        ]
