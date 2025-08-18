from __future__ import annotations
import os, json, time, hashlib, difflib, uuid
from typing import List, Dict, Any
from fastapi import FastAPI, HTTPException, Body
from pydantic import BaseModel
from .classifier import classify_issue
from .canon import load_canonical_map, suggest_canonical
from .ast_rewriters import apply_rewriters
from .llm_repair import llm_repair_if_needed
from .policy import can_auto_apply, requires_review
from .validation import run_validators
from .ledger import record_transformation
from .rules import load_rulesets

app = FastAPI(title="Code Doctor", version="0.1.0")

CANON = load_canonical_map()
RULESETS = load_rulesets()

class CodeFile(BaseModel):
    path: str
    language: str
    content: str

class FixRequest(BaseModel):
    files: List[CodeFile]
    error_log: str
    lint_report: Dict[str, Any] | None = None
    apply: bool = False
    strategy: str = "auto"  # auto|ast-only|llm-only
    risk_level: str = "medium"  # hint für policy
    metadata: Dict[str, Any] = {}

class FixResult(BaseModel):
    transformation_id: str
    applied: bool
    diffs: List[Dict[str, Any]]
    issues: List[Dict[str, Any]]
    actions: List[str]
    warnings: List[str]
    ledger_recorded: bool

@app.post("/heal", response_model=FixResult)
def heal(req: FixRequest):
    if not req.files:
        raise HTTPException(400,"No files submitted")
    t_id = str(uuid.uuid4())
    issues = classify_issue(req.error_log, req.lint_report)
    actions: List[str] = []
    warnings: List[str] = []

    # Step 1: Canonical Suggestions
    canonical_suggestions: Dict[str,str] = {}
    for issue in issues:
        if issue["type"] == "missing_symbol" and issue.get("symbol"):
            repl = suggest_canonical(issue["symbol"], CANON)
            if repl:
                canonical_suggestions[issue["symbol"]] = repl
                actions.append(f"map_symbol:{issue['symbol']}->{repl}")

    # Step 2: AST Rewriter pass
    rewritten_files = []
    for f in req.files:
        new_content, applied_rules = apply_rewriters(f.language, f.content, canonical_suggestions, RULESETS)
        if applied_rules:
            actions.extend([f"rule:{r}" for r in applied_rules])
        rewritten_files.append({
            "path": f.path,
            "language": f.language,
            "original": f.content,
            "modified": new_content
        })

    # Step 3: LLM Repair (optional)
    if req.strategy in ("auto","llm-only"):
        for rf in rewritten_files:
            rf["llm_modified"] = False
            maybe_more, llm_actions = llm_repair_if_needed(
                rf["modified"],
                rf["language"],
                issues,
                enable = (req.strategy != "ast-only")
            )
            if maybe_more and maybe_more != rf["modified"]:
                rf["modified"] = maybe_more
                rf["llm_modified"] = True
                actions.extend(llm_actions)

    # Step 4: Validation
    validation_findings = []
    for rf in rewritten_files:
        val = run_validators(rf["language"], rf["modified"])
        if val.get("warnings"):
            warnings.extend(val["warnings"])
        validation_findings.append(val)

    # Step 5: Diff
    diffs=[]
    for rf in rewritten_files:
        if rf["original"] == rf["modified"]:
            continue
        d = difflib.unified_diff(
            rf["original"].splitlines(),
            rf["modified"].splitlines(),
            fromfile=rf["path"]+":original",
            tofile=rf["path"]+":modified",
            lineterm=""
        )
        diff_text="\n".join(d)
        diffs.append({
            "path": rf["path"],
            "llm_modified": rf.get("llm_modified",False),
            "diff": diff_text
        })

    allow_apply = can_auto_apply(req.risk_level, actions)
    needs_review = requires_review(actions, req.risk_level)

    applied = False
    if req.apply:
        if not allow_apply or needs_review:
            warnings.append("Auto-Apply verweigert: Review erforderlich.")
        else:
            # In echter Umgebung: Patch auf Git Branch anwenden / PR erstellen
            applied = True

    # Step 6: Ledger
    ledger_payload = {
        "transformation_id": t_id,
        "issues": issues,
        "actions": actions,
        "applied": applied,
        "hash_bundle": hashlib.sha256(
            "".join(sorted(a for a in actions)).encode()
        ).hexdigest()
    }
    record_ok = record_transformation(ledger_payload)

    return FixResult(
        transformation_id=t_id,
        applied=applied,
        diffs=diffs,
        issues=issues,
        actions=actions,
        warnings=warnings,
        ledger_recorded=record_ok
    )

@app.get("/healthz")
def health():
    return {"ok": True, "canon": len(CANON), "rulesets": list(RULESETS.keys())}
