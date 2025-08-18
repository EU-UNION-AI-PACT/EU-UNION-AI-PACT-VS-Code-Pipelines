from typing import List

AUTO_APPLY_SAFE_ACTION_PREFIXES = {"rename:", "final_newline"}
HIGH_RISK_ACTIONS = {"llm_repair"}

def can_auto_apply(risk_level:str, actions:List[str])->bool:
    if risk_level in ("low","medium"):
        return not any(a.split(":")[0] in HIGH_RISK_ACTIONS for a in actions)
    return False

def requires_review(actions:List[str], risk_level:str)->bool:
    if any(a.startswith("llm_repair") for a in actions):
        return True
    if risk_level == "high":
        return True
    return False
