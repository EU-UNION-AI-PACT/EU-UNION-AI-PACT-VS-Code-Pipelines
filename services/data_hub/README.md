# Data Hub – Open Data & Open API Integration

## Ziele
- Vereinheitlichte Suche über CKAN-basierte Open Data Kataloge, SPARQL (Wikidata), OpenAPI Endpoints
- Normalisierte Resultate → RAG Kontext
- Caching & Source Fusionslogik
- Integration mit Chat Orchestrator für erweiterte Suche

## Architektur
```
[User Query] → Chat Orchestrator → Data Hub
                ↓
[CKAN APIs] [Wikidata SPARQL] [OpenAPI Discovery]
                ↓
[Fusion & Ranking] → [Cache] → [Results]
                ↓
[RAG Integration] ← [External Results]
```

## Endpunkte

### Suche
- `GET /search/unified?q=...&include=ckan,sparql,openapi` - Vereinheitlichte Suche
- `GET /search/opendata?q=...&limit=` - Nur Open Data (CKAN + SPARQL)
- `GET /search/openapi?q=...&limit=` - Nur OpenAPI Endpoints

### Sandbox
- `POST /sandbox/run` - Code-Ausführung in sicherer Umgebung

### Administration
- `POST /ingest/external` - Materialisierung in RAG
- `POST /cache/flush` - Cache leeren
- `GET /meta/sources` - Verfügbare Datenquellen

## Konfiguration

### Umgebungsvariablen
```bash
# CKAN Kataloge (komma-separiert)
OPEN_DATA_CKAN_BASES=https://data.europa.eu/api/hub/search,https://catalog.data.gov/api/3

# SPARQL Endpoint
SPARQL_ENDPOINT=https://query.wikidata.org/sparql

# OpenAPI Discovery
ALLOWED_OPENAPI_HOSTS=api.github.com,api.open-meteo.com,httpbin.org
OPENAPI_FETCH_TIMEOUT=20

# Cache
CACHE_TTL=3600

# Integration
SANDBOX_URL=http://exec-sandbox:8600/run
RAG_INGEST_URL=http://rag-api:8000/rag/query

# Vault (optional)
VAULT_ADDR=http://vault:8200
VAULT_ROLE=data-hub-role
```

## Sicherheit
- Host Allowlist für OpenAPI Discovery
- TTL Cache für Performance
- Query Hash Logging (keine Klartext-Speicherung)
- OPA Policy: `external_search` Aktion
- Rate Limiting (über Reverse Proxy empfohlen)

## Datenquellen

### CKAN (Open Data)
- EU Open Data Portal
- US Data.gov
- Nationale/regionale Kataloge

### SPARQL (Linked Data)
- Wikidata (Standard)
- Weitere SPARQL Endpoints konfigurierbar

### OpenAPI (API Discovery)
- GitHub API
- Open-Meteo Weather API
- Weitere über Allowlist

## Fusion & Ranking
- Term Matching
- Source-spezifische Gewichtung
- Length Penalty für sehr lange Beschreibungen
- Deduplizierung nach ID

## Integration mit Chat

### Tool Registration
```python
tools = [
    "open_data_search",   # CKAN + SPARQL
    "open_api_search",    # OpenAPI Discovery  
    "sandbox_execute"     # Code Execution
]
```

### Workflow
1. User Query → Tool Planning
2. Parallel Search (Local RAG + External)
3. Score Normalization & Fusion
4. Context Assembly für LLM

## Performance

### Caching
- TTL Cache (1 Stunde Standard)
- Query-Hash basierte Keys
- /cache/flush für manuelles Leeren

### Rate Limiting
- Externe APIs respektieren
- Backoff/Circuit Breaker empfohlen
- Monitoring via Prometheus

## Erweiterungsideen

### Kurz- bis mittelfristig
- **BM25 + Embedding Reranking**: Bessere Relevanzbewertung
- **Query Expansion**: Synonyme, Domain-Thesaurus
- **Circuit Breaker**: Robustheit bei API-Ausfällen
- **Persistent Materialization**: Häufige Datasets cachen

### Langfristig  
- **Federation**: Mehr SPARQL/GraphQL Endpoints
- **Entity Linking**: Wikidata Entities → Knowledge Graph
- **Adaptive Strategy**: Externe vs lokale Gewichtung
- **Live API Calls**: Sichere Parameter-Synthese

## Limitierungen
- OpenAPI Discovery über statische Liste (registry geplant)
- Einfaches Text-Matching (semantische Suche geplant)
- Rate Limits externer Dienste nicht zentral verwaltet
- SPARQL Query Template vereinfacht

## Monitoring
```bash
# Health Check
curl http://data-hub:8400/healthz

# Verfügbare Quellen
curl http://data-hub:8400/meta/sources

# Suche testen
curl "http://data-hub:8400/search/unified?q=climate&limit=3"
```

## Development

### Lokaler Start
```bash
cd services/data_hub
pip install -r requirements.txt
uvicorn src.app:app --reload --port 8400
```

### Docker Compose
```bash
docker-compose -f docker-compose.data-hub.yml up -d
```

### Tests
```bash
pytest services/data_hub/tests/
```
