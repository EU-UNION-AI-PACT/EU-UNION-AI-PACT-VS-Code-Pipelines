from __future__ import annotations
from typing import List, Dict
import math

def normalize_scores(local_docs: List[Dict], external_docs: List[Dict]):
    """Normalize scores from different sources"""
    # Assume local_docs contain 'score' (sim) 0..1, external maybe variety
    # Simple scaling: external raw score -> sigmoid normalisierung
    def sigmoid(x): 
        return 1/(1+math.exp(-x))
    
    for e in external_docs:
        base = e.get("score",0.0)
        e["norm_score"]= sigmoid(base)
        
    for l in local_docs:
        l["norm_score"]= l.get("score",0.0)
        
    return local_docs, external_docs

def fuse_two(local_docs: List[Dict], external_docs: List[Dict], k:int=8):
    """Fuse local and external search results"""
    local_docs, external_docs = normalize_scores(local_docs, external_docs)
    combined = local_docs + external_docs
    
    # Sort by normalized score
    combined = sorted(combined, key=lambda x: x.get("norm_score",0.0), reverse=True)
    
    # Deduplicate by content similarity (simple)
    final = []
    seen_titles = set()
    
    for doc in combined:
        title = doc.get("title", "").lower()
        if title and title not in seen_titles:
            seen_titles.add(title)
            final.append(doc)
            if len(final) >= k:
                break
                
    return final[:k]

def boost_local_vs_external(docs: List[Dict], local_boost: float = 1.1):
    """Boost local documents vs external ones"""
    for doc in docs:
        source = doc.get("source", "")
        if "local" in source or "rag" in source:
            doc["norm_score"] = doc.get("norm_score", 0.0) * local_boost
    return docs
