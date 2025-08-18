from __future__ import annotations
import os, sys, io, json, time, signal, resource
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import uvicorn

EXEC_TIMEOUT = int(os.getenv("EXEC_TIMEOUT","4"))
MAX_CODE_BYTES = int(os.getenv("MAX_CODE_BYTES","4000"))
MAX_OUTPUT_BYTES = int(os.getenv("MAX_OUTPUT_BYTES","8000"))

app=FastAPI(title="Exec Sandbox", version="0.1.0")

class RunReq(BaseModel):
    language: str
    code: str
    input: str|None=None

def limit_resources():
    """Set resource limits for safe execution"""
    try:
        resource.setrlimit(resource.RLIMIT_CPU, (EXEC_TIMEOUT, EXEC_TIMEOUT))
        resource.setrlimit(resource.RLIMIT_AS, (256*1024*1024, 256*1024*1024))
        resource.setrlimit(resource.RLIMIT_FSIZE, (1024*1024,1024*1024))
    except Exception:
        pass  # May not work in all environments

@app.get("/healthz")
def health():
    return {"ok":True, "timeout": EXEC_TIMEOUT, "max_code": MAX_CODE_BYTES}

@app.post("/run")
def run(r: RunReq):
    if r.language.lower() not in ("python","py"):
        raise HTTPException(400,"Only python sandbox supported in demo")
    
    if len(r.code.encode())>MAX_CODE_BYTES:
        raise HTTPException(400,f"Code too large (max {MAX_CODE_BYTES} bytes)")
    
    code = r.code
    stdin_data = r.input or ""
    buff_out = io.StringIO()
    buff_err = io.StringIO()

    def timeout_handler(signum, frame):
        raise TimeoutError("Execution timeout")

    # Set alarm for timeout (Unix only)
    old_handler = None
    try:
        old_handler = signal.signal(signal.SIGALRM, timeout_handler)
        signal.alarm(EXEC_TIMEOUT)
    except Exception:
        pass  # Windows doesn't support SIGALRM

    g = {"__name__":"__sandbox__", "__builtins__": __builtins__}
    
    try:
        limit_resources()
        start=time.time()
        
        # Redirect stdout/stderr
        old_stdout, old_stderr = sys.stdout, sys.stderr
        sys.stdout, sys.stderr = buff_out, buff_err
        
        # Execute code
        exec(compile(code,"<sandbox>","exec"), g, g)
        
        # If there's a main function, call it
        if "main" in g and callable(g["main"]):
            try:
                res = g["main"](stdin_data)
                print(f"__MAIN_RETURN__={res}")
            except Exception as e:
                print(f"__MAIN_ERROR__={e}")
        
        # Restore stdout/stderr
        sys.stdout, sys.stderr = old_stdout, old_stderr
        elapsed = time.time()-start
        
    except TimeoutError as te:
        sys.stdout, sys.stderr = old_stdout, old_stderr
        return {
            "status":"timeout",
            "stdout":buff_out.getvalue()[:MAX_OUTPUT_BYTES],
            "stderr":str(te)
        }
    except Exception as e:
        sys.stdout, sys.stderr = old_stdout, old_stderr
        return {
            "status":"error",
            "stdout":buff_out.getvalue()[:MAX_OUTPUT_BYTES],
            "stderr":buff_err.getvalue()[:MAX_OUTPUT_BYTES] + str(e)
        }
    finally:
        try:
            signal.alarm(0)  # Cancel alarm
            if old_handler:
                signal.signal(signal.SIGALRM, old_handler)
        except Exception:
            pass

    return {
        "status":"ok",
        "elapsed_ms": int(elapsed*1000),
        "stdout": buff_out.getvalue()[:MAX_OUTPUT_BYTES],
        "stderr": buff_err.getvalue()[:MAX_OUTPUT_BYTES]
    }

if __name__=="__main__":
    uvicorn.run("sandbox_app:app",host="0.0.0.0",port=8600)
