import math
from typing import List
import numpy as np

def mmr(query_embedding, doc_embeddings, docs, k=5, lambda_mult=0.6):
    selected=[]
    candidates=list(range(len(docs)))
    while len(selected)<min(k, len(docs)):
        best=None
        best_score=-1
        for idx in candidates:
            relevance=1 - doc_embeddings[idx]["distance"]  # assuming 'distance'
            diversity=0
            for s in selected:
                sim=cosine(doc_embeddings[idx]["vec"], doc_embeddings[s]["vec"])
                diversity=max(diversity, sim)
            score=lambda_mult*relevance - (1-lambda_mult)*diversity
            if score>best_score:
                best_score=score; best=idx
        selected.append(best)
        candidates.remove(best)
    return [docs[i] for i in selected]

def cosine(a,b):
    a=np.array(a); b=np.array(b)
    return float(a.dot(b)/( (a*a).sum()**0.5 * (b*b).sum()**0.5 + 1e-9))
