from __future__ import annotations
import httpx, os

SANDBOX_URL = os.getenv("SANDBOX_URL")

async def sandbox_execute(language:str, code:str, input_data:str|None):
    """Execute code in sandbox environment"""
    if not SANDBOX_URL:
        return {"error":"sandbox_not_configured"}
    
    try:
        async with httpx.AsyncClient(timeout=15) as client:
            r = await client.post(SANDBOX_URL, json={
                "language":language,
                "code":code,
                "input":input_data
            })
            r.raise_for_status()
            return r.json()
    except Exception as e:
        return {"error": f"sandbox_error: {str(e)}"}
