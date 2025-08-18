from __future__ import annotations
import os, httpx
from typing import List, Dict, Any

SPARQL_ENDPOINT = os.getenv("SPARQL_ENDPOINT","https://query.wikidata.org/sparql")

SPARQL_TEMPLATE = """
SELECT ?item ?itemLabel ?description WHERE {{
  ?item rdfs:label ?itemLabel .
  ?itemLabel bif:contains "{query}" .
  FILTER(LANG(?itemLabel) = "en")
  SERVICE wikibase:label {{ bd:serviceParam wikibase:language "en". }}
  OPTIONAL {{ ?item schema:description ?description FILTER(LANG(?description)="en") }}
}} LIMIT {limit}
"""

async def search_wikidata(q: str, limit:int=10)->List[Dict[str,Any]]:
    """Search Wikidata via SPARQL"""
    # Escape quotes in query
    clean_q = q.replace('"','').replace("'","")
    query = SPARQL_TEMPLATE.format(query=clean_q, limit=min(limit,25))
    
    headers={
        "Accept":"application/sparql-results+json",
        "User-Agent":"DataHub/0.1"
    }
    
    try:
        async with httpx.AsyncClient(timeout=25) as client:
            r = await client.get(SPARQL_ENDPOINT, params={"query": query}, headers=headers)
            r.raise_for_status()
            js=r.json()
            out=[]
            
            for b in js.get("results",{}).get("bindings",[]):
                uri=b.get("item",{}).get("value")
                title=b.get("itemLabel",{}).get("value","")
                desc=b.get("description",{}).get("value","")
                
                out.append({
                    "source": "wikidata",
                    "kind": "entity",
                    "id": uri,
                    "title": title,
                    "description": desc,
                    "url": uri,
                    "score": 0.0
                })
            return out
    except Exception as e:
        print(f"Wikidata search error: {e}")
        return []
