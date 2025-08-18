# Lokaler NLP + IP Schutz Stack

## Ziele
- Lokale Verarbeitung sensibler Texte (verschlüsselter Host-Speicher empfohlen: LUKS / dm-crypt).
- Automatisches Klassifizieren & Policy-Durchsetzung (OPA).
- Hashing & Ledger für Ursprung / Integrität.
- Vektor-Embeddings für interne Suche.
- Basis-Funktionen für Prior-Art / Patent-Recherche (WIPO/EPO Platzhalter).

## Schnellstart
```bash
cp .env.nlp.example .env.nlp
# Werte in .env.nlp anpassen
docker compose -f docker-compose.nlp.yml --env-file .env.nlp up --build

# Ingestion Beispiel:
curl -X POST -H "x-auth-token: $INTERNAL_API_TOKEN" -F file=@test.txt http://localhost:8080/ (Gateway Endpunkte erweitern!)
# Direkt docproc (ohne Gateway Security) – nur DEV:
curl -F file=@test.txt http://localhost:8100/ingest
```

## Komponenten
- **Postgres + pgvector**: Embeddings + Metadaten
- **embedding**: SentenceTransformer Servicemodell
- **docproc**: Ingestion, Chunking, Klassifikation, Hashing, Embedding Speicherung
- **ip-guard**: Ledger-Verifikation, Prior-Art Query (Platzhalter)
- **opa**: Policy Engine
- **gateway**: API Aggregation + Auth Header
- **security/**: Policies & Klassifizierung

## Sicherheit & Compliance
- Festplattenverschlüsselung hostseitig (nicht im Compose behandelbar).
- Policy Kontrolle via OPA (Rechte: ingest/query/export).
- Klassifizierungs-Pattern (regex-basiert). Für Produktionsumgebung: fein granulare NLP NER / DLP Tools.
- Hash + ledger.jsonl (append-only) -> für Audit signieren (z.B. tagesweise cosign sign-blob).
- Optional: Zeitstempel Service (RFC 3161 TSA) oder OpenTimestamps zum beweisbaren Einfrierstatus.

## IP Schutz & Workflows
1. Ingest → Klassifikation → Hash → Ledger Append.
2. (Optional) Signatur / Merkle-Tree Hash Batches → Off-chain Notarisierung (z.B. Bitcoin OpenTimestamps) oder interne PKI.
3. Vor Veröffentlichung: Prior-Art Queries (WIPO/EPO) manuell/halbautomatisch.
4. Dokumentation der Abfragen (Query + Zeitpunkt) im Ledger (Erweiterung ip-guard).
5. Rechtliche Einreichung weiterhin über offizielle Portale.

## WIPO & EPO Hinweise
- WIPO PATENTSCOPE & EPO OPS haben Nutzungsbedingungen & Rate Limits.
- Scripts hier nur Gerüst. Implementierung:
  - EPO OPS: OAuth2 Token holen, dann /rest-services/published-data/search
  - Ergebnisse (Abstracts) NICHT massenhaft speichern ohne Erlaubnis.

## Erweiterungsvorschläge
- Volltext-Suchindex (OpenSearch) für interne Corpus-Suche.
- Document Watermarking (z.B. Zero-Width Unicode Patterns oder semantische Variation) – Vorsicht bzgl. Robustheit & Erkennung.
- Content Provenance (C2PA / CAI Manifest): JSON-LD Signieren und mit Artefakten bündeln.
- DSGVO / Datenschutz: PII-Redaktion (NER + Maskierung) vor Persistierung.

## Embedding & Suche
SQL Beispiel (cosine similarity):
```sql
SELECT doc_id, chunk_index, 1 - (embedding <=> query_vec) AS score
FROM embeddings
ORDER BY embedding <=> query_vec
LIMIT 10;
```
(query_vec = Param via psycopg2: vector literal)

## OPA Policy Test
```bash
curl -X POST http://localhost:8181/v1/data/nlp/allow -d '{"input":{"action":"ingest","classification":"internal","user_roles":["data-steward"]}}'
```

## Ledger Integrität
```bash
sha256sum nlp/storage/ledger/ledger.jsonl > nlp/storage/ledger/ledger.jsonl.sha256
# Optional signieren (minisign oder cosign sign-blob)
./nlp/scripts/provenance_batch_sign.sh
```

## Backup / Disaster Recovery
- Postgres: WAL Archiving (pgBackRest o. ä.)
- ledger.jsonl: append-only in WORM Storage replizieren
- Modellcache kann reproduziert werden

## Hardening ToDo
- Resource Limits in Compose
- mTLS zwischen Services (Envoy / Traefik Mesh)
- Secrets in Vault statt .env
- Rate Limiting / AuthZ (OPA + ext. Identity Provider)

## Integration mit EU AI Pact Stack
Dieses NLP/IP-System kann mit dem bestehenden MCP/WASM Stack integriert werden:
- WASM-Plugin für IP-Validation vor Dokumentenverarbeitung
- MCP-Konnektoren für externe Patent-Datenbanken
- Gemeinsame Policy-Engine (OPA) für beide Stacks

## Rechtlicher Hinweis
Dieses Repo liefert technische Bausteine. Rechtlich bindende Workflows (Patentanmeldung, Urheberrechtsdeponierung, Beweisführung) müssen manuell / offiziell erfolgen.
