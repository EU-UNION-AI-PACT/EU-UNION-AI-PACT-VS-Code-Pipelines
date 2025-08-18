# Code Doctor – Transformative Auto-Healing

## Zweck
Automatisiert die Korrektur von Codeproblemen (falsche Funktions-/Namen, Missing Symbols, leichte Strukturfehler) und orchestriert ggf. LLM-Reparaturen für komplexere Logik.

## Workflow
1. `/heal` (POST) mit:
   ```json
   {
     "files":[{"path":"module.py","language":"python","content":"..."}],
     "error_log":"Traceback ... NameError: name 'getData' is not defined",
     "apply": false
   }
   ```
2. Service klassifiziert Issues.
3. Canonical Mapping (function_canon_map.json).
4. AST / Text Rewriter.
5. Optional LLM Repair (nur bei high-risk Issues).
6. Validator (Warnungen).
7. Diff zurück.
8. Optional auto apply (Policy) → später Git Branch / PR.

## API Endpoints

### POST /heal
Hauptendpoint für Code-Heilung.

**Request Body:**
```json
{
  "files": [
    {
      "path": "example.py",
      "language": "python", 
      "content": "def getData():\n    return data"
    }
  ],
  "error_log": "NameError: name 'getData' is not defined",
  "lint_report": null,
  "apply": false,
  "strategy": "auto",
  "risk_level": "medium",
  "metadata": {}
}
```

**Response:**
```json
{
  "transformation_id": "uuid-string",
  "applied": false,
  "diffs": [
    {
      "path": "example.py",
      "llm_modified": false,
      "diff": "unified diff format"
    }
  ],
  "issues": [
    {
      "type": "missing_symbol",
      "symbol": "getData",
      "raw": "NameError: name 'getData' is not defined"
    }
  ],
  "actions": ["map_symbol:getData->fetch_data"],
  "warnings": [],
  "ledger_recorded": true
}
```

### GET /healthz
Health check endpoint.

**Response:**
```json
{
  "ok": true,
  "canon": 20,
  "rulesets": ["python_basic", "javascript_basic"]
}
```

## Sicherheit
- Kein automatisches Anwenden bei high risk.
- LLM Code wird zusätzlich validiert (no eval/exec).
- Ledger Hash für Nachvollziehbarkeit.
- Policy-basierte Auto-Apply Entscheidungen.

## Erweiterungen
- Multi-Language AST (LibCST, jscodeshift, go/ast).
- Semantic Tests (Unit Tests ausführen + Coverage Check).
- Mutation Score vor/nach Repair.
- Explainability: Warum wurde Umbenennung gemacht?

## Konfiguration

### Environment Variables
- `OPENAI_API_KEY`: OpenAI API Key für LLM Repairs
- `OPENAI_API_BASE`: Base URL für OpenAI API (default: https://api.openai.com/v1)
- `OPENAI_MODEL`: OpenAI Model (default: gpt-4o-mini)
- `CODE_DOCTOR_LEDGER`: Pfad zum Ledger Directory (default: ./code-doctor-ledger)

### Canonical Mapping
Funktionsnamen werden über `data/function_canon_map.json` gemappt:
```json
{
  "getData": "fetch_data",
  "processData": "process_data",
  "calcHash": "compute_hash"
}
```

### Rulesets
YAML-basierte Regeln in `ruleset/`:
- `python_basic.yaml`: Python Style Rules
- `javascript_basic.yaml`: JavaScript/TypeScript Rules

## Docker Deployment
```bash
docker build -t code-doctor .
docker run -p 8500:8500 -e OPENAI_API_KEY=your-key code-doctor
```

## Integration in Gesamtsystem
- TechOps: ServiceMonitor für code-doctor
- Vault: Optionale Signierung transformierter Diffs
- Pipeline Hook: CI Job „code-heal" vor PR Review
- RAG/Chat: Tool „code_fix" registrieren

## Testing
```bash
cd services/code_doctor
python -m pytest tests/ -v
```

## Limitierungen
Beispielhaft – echte Produktionsintegration benötigt robustere Parser & tieferen Kontext.
AST-Rewriting ist vereinfacht; echte Implementierung sollte LibCST (Python) oder jscodeshift (JS/TS) verwenden.
