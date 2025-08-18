from __future__ import annotations
from typing import List, Dict, Any
from math import log

def fuse_results(query: str, docs: List[Dict[str,Any]], limit:int=10)->List[Dict[str,Any]]:
    """Fuse and rank results from multiple sources"""
    # Simple scoring: term match boost + length penalty
    q_terms = set(query.lower().split())
    
    for d in docs:
        title = d.get("title","")
        description = d.get("description","")
        text = (title + " " + description).lower()
        
        # Count matching terms
        matches = sum(1 for t in q_terms if t in text)
        
        # Penalize very long descriptions
        length_penalty = 1/(1+log(max(10,len(text))))
        
        # Boost by source type
        source_boost = 1.0
        if d.get("kind") == "dataset":
            source_boost = 1.2
        elif d.get("kind") == "entity":
            source_boost = 1.1
        elif d.get("kind") == "api_operation":
            source_boost = 1.0
            
        d["score"] = matches * 2.0 * length_penalty * source_boost
    
    # Sort by score
    ranked = sorted(docs, key=lambda x: x["score"], reverse=True)
    
    # Deduplicate by id
    seen=set()
    final=[]
    for r in ranked:
        if r["id"] in seen: 
            continue
        seen.add(r["id"])
        final.append(r)
        if len(final)>=limit: 
            break
            
    return final
