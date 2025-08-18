import hashlib
import structlog

log = structlog.get_logger()

def hash_query(q:str)->str:
    return hashlib.sha256(q.encode()).hexdigest()[:16]
