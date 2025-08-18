# 🇪🇺 EU AI Pact - VS Code Pipeline Tools

Ein umfassendes Set von Entwicklungstools für die Einhaltung des EU AI Acts in VS Code Entwicklungsumgebungen.

## 🏗️ Architektur

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │   MCP Server    │    │ Wasmtime Host   │
│   (Static)      │◄──►│  (Node.js)      │    │   (Rust)        │
│                 │    │                 │    │                 │
│ EU AI Act       │    │ AI Compliance   │    │ WASM Validator  │
│ Compliance UI   │    │ Tools & APIs    │    │ Plugins         │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │ Nginx Proxy     │
                    │ (Reverse Proxy) │
                    └─────────────────┘
```

## 🚀 Komponenten

### 1. **DevContainer Setup**
- Node.js 20 + Rust + Wasmtime
- VS Code Extensions für Rust und TypeScript
- Automatische Tool-Installation

### 2. **MCP Server (Model Context Protocol)**
- EU AI Act Compliance Tools
- Risk Assessment APIs
- RESTful Interface
- UUID Generation & Validation

### 3. **Wasmtime Host (Rust)**
- WASM-basierte AI Validierung
- Isolierte Plugin-Ausführung
- Fuel-limitierte Ausführung
- EU AI Act Compliance Scoring

### 4. **WASM Validator Plugin**
- AI System Compliance Bewertung
- Risk Category Assessment
- Transparency Requirements
- EU AI Act konforme Validierung

### 5. **Web Interface**
- Interaktive Tools für Entwickler

### 6. **NLP/IP Schutz Stack (NEU)**
- Lokale Dokumentenverarbeitung mit IP-Schutz
- Automatische Klassifizierung & Policy-Durchsetzung
- Vector-Embeddings für semantische Suche
- Prior-Art Recherche (WIPO/EPO Integration)
- Hash-basierte Provenance & Integrität
- OPA Policy Engine für Zugriffskontrolle
- Real-time AI Compliance Checks
- Risk Assessment Dashboard
- Integration Testing

## 🛠️ Schnellstart

### DevContainer (Empfohlen)

1. **Repository öffnen:**
   ```bash
   code .
   ```

2. **In Container öffnen:**
   - VS Code: `Cmd/Ctrl + Shift + P` → "Reopen in Container"
   - Warten auf Container-Build und Post-Create Script

3. **Services starten:**
   ```bash
   cp .env.example .env
   docker compose up --build
   ```

4. **Frontend öffnen:**
   - Browser: http://localhost
   - MCP API: http://localhost/mcp/tools
   - WASM Validator: http://localhost/validate/healthz

### Lokale Entwicklung

```bash
# Dependencies installieren
cd services/mcp-server && npm install
rustup target add wasm32-wasi

# WASM Plugin bauen
./scripts/build-wasm.sh

# Services einzeln starten
npm run dev --prefix services/mcp-server     # Port 7000
cargo run --manifest-path services/wasmtime-host/Cargo.toml  # Port 8080
```

## 🧪 Testing

```bash
# Service Tests
./scripts/test-services.sh

# Node.js Client
cd clients/node && npm install && node index.js

# Python Client  
cd clients/python && pip install -r requirements.txt && python client.py
```

## 🔧 API Referenz

### MCP Server Endpoints

```http
GET  /mcp/healthz                 # Health Check
GET  /mcp/tools                   # Verfügbare Tools
POST /mcp/invoke                  # Tool Ausführung
GET  /mcp/context                 # Projekt Kontext
```

**Tool Invocation Beispiel:**
```json
POST /mcp/invoke
{
  "tool": "validate-ai-compliance",
  "args": {
    "system": "VS Code AI Assistant",
    "riskLevel": "limited"
  }
}
```

### Wasmtime Validator

```http
GET  /validate/healthz            # Health Check
POST /validate/validate           # WASM Validierung
```

**Validation Beispiel:**
```json
POST /validate/validate
{
  "validator": "ai-validator",
  "payload": {
    "aiSystem": {
      "name": "Code Assistant",
      "type": "development-tool",
      "riskLevel": "limited"
    }
  }
}
```

## 🏭 Kubernetes Deployment

### Voraussetzungen
- Kubernetes Cluster mit Ingress Controller
- Optional: cert-manager für TLS

### Deployment
```bash
# ConfigMap anwenden
kubectl apply -f k8s/configmap.yaml

# Services deployen
kubectl apply -f k8s/deployment-mcp.yaml
kubectl apply -f k8s/deployment-wasmhost.yaml
kubectl apply -f k8s/deployment-web.yaml

# Ingress konfigurieren
kubectl apply -f k8s/ingress.yaml

# Status prüfen
kubectl get pods,services,ingress
```

### DNS Konfiguration
```bash
# /etc/hosts (für lokales Testing)
127.0.0.1 eu-ai-pact.example.com
```

## 🔒 EU AI Act Compliance Features

### 1. **Risk Assessment**
- **Unacceptable Risk**: Verbotene AI-Systeme
- **High Risk**: Strenge Auflagen (z.B. kritische Infrastruktur)
- **Limited Risk**: Transparenzpflichten
- **Minimal Risk**: Freiwillige Maßnahmen

### 2. **Compliance Validation**
- Automatisierte Risiko-Kategorisierung
- Dokumentationsanforderungen
- Human Oversight Bewertung
- Transparenz-Scores

### 3. **WASM-basierte Isolation**
- Sichere Plugin-Ausführung
- Resource-limitierte Validierung
- Fuel-basierte CPU-Limits
- Deterministische Bewertung

## 🧩 Erweiterungen

### Neue WASM Validator hinzufügen

1. **Neuen Validator erstellen:**
   ```bash
   cargo new --lib wasm-plugins/my-validator
   cd wasm-plugins/my-validator
   ```

2. **Cargo.toml konfigurieren:**
   ```toml
   [lib]
   crate-type = ["cdylib"]
   ```

3. **Export Funktionen implementieren:**
   ```rust
   #[no_mangle]
   pub extern "C" fn my_validation(input: i32) -> i32 {
       // Validation logic
       input * 2
   }
   ```

4. **Build und Deploy:**
   ```bash
   cargo build --target wasm32-wasi --release
   cp target/wasm32-wasi/release/my_validator.wasm validators/
   ```

### MCP Tools erweitern

```javascript
// In services/mcp-server/src/index.js
if (tool === "my-new-tool") {
  return res.json({ 
    tool, 
    output: "Tool result", 
    status: "ok" 
  });
}
```

## 🛡️ Sicherheit

### Container Security
- Non-root User (UID 1000)
- Dropped Capabilities
- Resource Limits
- Security Contexts

### WASM Isolation
- Fuel-limitierte Ausführung
- Memory Isolation
- Deterministic Execution
- No System Access

### Network Security
- Service Mesh kompatibel
- NetworkPolicies verfügbar
- TLS-ready (cert-manager)
- Rate Limiting möglich

## 📊 Monitoring & Observability

### Health Checks
- Kubernetes Readiness/Liveness Probes
- Service Health Endpoints
- Docker Compose Health Checks

### Metrics (Erweiterbar)
- Prometheus Exporter Integration
- WASM Execution Metrics
- Compliance Score Tracking
- API Response Times

## 🚀 CI/CD Integration

### GitHub Actions (Vorbereitet)
```yaml
# Beispiel Workflow
- name: Build WASM
  run: ./scripts/build-wasm.sh

- name: Test Services  
  run: ./scripts/test-services.sh

- name: Build & Push Images
  # Docker build und registry push
```

### Security Scanning
- SBOM Generation (Syft)
- Vulnerability Scanning (Trivy)
- Code Quality (SonarQube)
- Supply Chain Security (Cosign)

## 🔗 Client Libraries

### Node.js
```javascript
import { EUAIPactClient } from './clients/node/index.js';
const client = new EUAIPactClient();
const result = await client.validateAICompliance("MyAI");
```

### Python
```python
from clients.python.client import EUAIPactClient
client = EUAIPactClient()
result = client.validate_ai_compliance("MyAI")
```

## � NLP/IP Schutz Stack

Der lokale NLP/IP Schutz Stack bietet sichere Dokumentenverarbeitung mit Intellectual Property Schutz:

```bash
# NLP Stack starten
cp .env.nlp.example .env.nlp
# Konfiguration anpassen in .env.nlp
docker compose -f docker-compose.nlp.yml --env-file .env.nlp up --build
```

### Features
- **Lokale Verarbeitung**: Kein Cloud-Upload sensibler Dokumente
- **Automatische Klassifizierung**: Vertraulichkeitsstufen per Regex/NLP  
- **IP-Schutz**: Hash-basierte Provenance & Integrität
- **Prior-Art Recherche**: WIPO/EPO Integration (Platzhalter)
- **Vector Search**: pgvector für semantische Dokumentensuche
- **Policy Engine**: OPA für Zugriffskontrolle

### Endpoints
```http
POST /ingest                      # Dokument Upload & Processing
POST /verify                      # Hash Verifikation
GET  /wipo/prior_art             # WIPO Prior-Art Suche
GET  /epo/ops/query              # EPO Patent Suche
```

### Verwendung
```bash
# Dokument hochladen
curl -F file=@document.txt http://localhost:8100/ingest

# OPA Policy testen
curl -X POST http://localhost:8181/v1/data/nlp/allow \
  -d '{"input":{"action":"ingest","classification":"internal","user_roles":["data-steward"]}}'

# Ledger Integrität prüfen
./nlp/scripts/provenance_batch_sign.sh
```

Siehe `nlp/README.md` für detaillierte Anleitung.

## �📚 Weitere Ressourcen

- [EU AI Act Official Text](https://eur-lex.europa.eu/eli/reg/2024/1689/oj)
- [Wasmtime Documentation](https://docs.wasmtime.dev/)
- [Model Context Protocol](https://github.com/modelcontextprotocol)
- [VS Code DevContainers](https://code.visualstudio.com/docs/devcontainers/containers)

## 🤝 Contributing

1. Fork das Repository
2. Feature Branch erstellen (`git checkout -b feature/amazing-feature`)
3. Changes committen (`git commit -m 'Add amazing feature'`)
4. Branch pushen (`git push origin feature/amazing-feature`)
5. Pull Request öffnen

## 📄 Lizenz

Apache 2.0 License - siehe [LICENSE](LICENSE) für Details.

---

**🇪🇺 EU AI Pact Compliance Tools** - Entwickelt für sichere und konforme AI-Entwicklung in Europa.
