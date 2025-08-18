import re
from typing import Dict

def run_validators(language:str, code:str)->Dict:
    warnings=[]
    if language.lower().startswith("py"):
        if "exec(" in code:
            warnings.append("Use of exec() flagged")
        if re.search(r"print\(.+DEBUG", code):
            warnings.append("DEBUG print found")
        if "eval(" in code:
            warnings.append("Use of eval() flagged")
        if "__import__" in code:
            warnings.append("Use of __import__() flagged")
        if "os.system" in code:
            warnings.append("Use of os.system() flagged")
        if "subprocess.call" in code and "shell=True" in code:
            warnings.append("Shell injection risk with subprocess.call")
    if language.lower() in ("js","ts"):
        if "eval(" in code:
            warnings.append("Use of eval() flagged")
        if "innerHTML" in code:
            warnings.append("Potential XSS with innerHTML")
        if "document.write" in code:
            warnings.append("Use of document.write() flagged")
    return {"warnings": warnings}
