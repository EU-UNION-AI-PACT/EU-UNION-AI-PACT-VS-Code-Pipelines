from sentence_transformers import CrossEncoder
from typing import List, Dict

_model=None
def load_model(name="cross-encoder/ms-marco-MiniLM-L-6-v2"):
    global _model
    if _model is None:
        _model=CrossEncoder(name)
    return _model

def rerank(query: str, docs: List[Dict], top_k:int=5):
    model=load_model()
    pairs=[[query, d["text"]] for d in docs]
    scores=model.predict(pairs)
    for d,s in zip(docs,scores):
        d["rerank_score"]=float(s)
    reranked=sorted(docs, key=lambda x: x["rerank_score"], reverse=True)[:top_k]
    return reranked
