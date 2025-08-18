from __future__ import annotations
from typing import Tuple, Dict, List, Any

def apply_rewriters(language:str, content:str, symbol_map:Dict[str,str], rulesets:Dict[str,Any])->Tuple[str,List[str]]:
    applied=[]
    new=content
    if language.lower() in ("py","python"):
        # naive rename for canonical symbols (only function calls / defs)
        for old, new_name in symbol_map.items():
            if old in new:
                before=new
                new = rename_python_identifier(new, old, new_name)
                if new!=before:
                    applied.append(f"rename:{old}->{new_name}")
        # style enforcement placeholder
        if "python_basic" in rulesets:
            if not new.endswith("\n"):
                new+="\n"
                applied.append("final_newline")
    elif language.lower() in ("js","ts","javascript","typescript"):
        for old, new_name in symbol_map.items():
            if old in new:
                before=new
                new = rename_js_identifier(new, old, new_name)
                if new!=before:
                    applied.append(f"rename:{old}->{new_name}")
    return new, applied

def rename_python_identifier(code:str, old:str, new:str)->str:
    # Very naive: real impl -> LibCST
    import re
    pattern = r"\b" + re.escape(old) + r"\b"
    return re.sub(pattern, new, code)

def rename_js_identifier(code:str, old:str, new:str)->str:
    import re
    pattern = r"\b" + re.escape(old) + r"\b"
    return re.sub(pattern, new, code)
