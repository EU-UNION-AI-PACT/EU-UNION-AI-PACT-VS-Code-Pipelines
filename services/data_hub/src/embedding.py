from sentence_transformers import SentenceTransformer
import threading

_lock = threading.Lock()
_model = None

def get_embedder():
    global _model
    with _lock:
        if _model is None:
            _model = EmbedderWrapper(SentenceTransformer("sentence-transformers/all-MiniLM-L12-v2"))
    return _model

class EmbedderWrapper:
    def __init__(self, model): 
        self.model = model
        
    def embed(self, texts):
        if not texts: 
            return []
        return self.model.encode(texts, convert_to_numpy=True).tolist()
