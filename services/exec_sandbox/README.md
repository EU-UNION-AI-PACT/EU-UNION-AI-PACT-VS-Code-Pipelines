# Exec Sandbox (Demo)

## Zweck

Mini-Ausführungsumgebung für kurze Analyse- und Transformations-Code-Snippets (Python).

## Sicherheitseinschränkungen

- **CPU/Memory Limits**: Begrenzte Ressourcen pro Ausführung
- **Timeout**: Maximale Ausführungszeit (4 Sekunden)
- **Kein Netzwerk**: Isolierte Ausführung ohne externe Zugriffe
- **Read-Only**: Kein Schreibzugriff außer /tmp (tmpfs)
- **Restricted Imports**: Gefährliche Module blockiert

## Architektur

```
[Code Request] → [Resource Limits] → [Isolated Execution] → [Output Capture]
                        ↓
                [Timeout Handler] → [Security Validation] → [Results]
```

## API

### Endpunkte
- `POST /run` - Code ausführen
- `GET /healthz` - Health Check

### Request Format
```json
{
  "language": "python",
  "code": "print('Hello World')",
  "input": "optional input data"
}
```

### Response Format
```json
{
  "status": "ok|error|timeout",
  "elapsed_ms": 123,
  "stdout": "Hello World\n",
  "stderr": ""
}
```

## Sicherheitsmaßnahmen

### Ressourcen-Limits
- CPU: 4 Sekunden
- Memory: 256MB
- Dateigröße: 1MB
- Prozesse: 128

### Code-Validierung
- Blockierte Imports: `os`, `subprocess`, `socket`
- Blockierte Funktionen: `eval`, `exec`, `__import__`
- Maximale Code-Größe: 4KB

### Container-Sicherheit
```dockerfile
USER sandbox              # Non-root user
read_only: true           # Read-only filesystem
no-new-privileges: true   # No privilege escalation
pids_limit: 128          # Process limit
mem_limit: 256m          # Memory limit
```

## Verwendung

### Einfaches Beispiel
```bash
curl -X POST http://exec-sandbox:8600/run \
  -H "Content-Type: application/json" \
  -d '{
    "language": "python",
    "code": "print(2 + 2)"
  }'
```

### Mit Input-Daten
```bash
curl -X POST http://exec-sandbox:8600/run \
  -H "Content-Type: application/json" \
  -d '{
    "language": "python", 
    "code": "data = input(); print(f\"Processed: {data}\")",
    "input": "test data"
  }'
```

### Mit main() Funktion
```python
def main(input_data):
    numbers = [int(x) for x in input_data.split()]
    return sum(numbers)

# Automatisch aufgerufen wenn vorhanden
```

## Integration

### Chat Orchestrator
```python
result = await sandbox_execute(
    language="python",
    code=user_code,
    input_data=data_sample
)
```

### Data Hub
```python
# Über Data Hub Proxy
response = await httpx.post(
    f"{DATA_HUB_URL}/sandbox/run",
    json={"language": "python", "code": code}
)
```

## Limitierungen

### Aktueller Stand
- **Nur Python**: Andere Sprachen nicht implementiert
- **Einfache Isolation**: Nicht für unvertrauenswürdigen Code geeignet
- **Keine Persistenz**: Zustand geht zwischen Aufrufen verloren
- **Basic Security**: Produktions-Härtung erforderlich

### Nicht geeignet für
- Produktions-User-Code ohne weitere Isolation
- Langläufige Berechnungen
- Netzwerk-abhängige Operationen
- Dateisystem-intensive Tasks

## Zukünftige Härtung

### Geplante Verbesserungen
- **seccomp Profile**: Syscall-Filtering
- **gVisor/Firecracker**: Kernel-Level Isolation
- **WASI/Wasmtime**: WebAssembly für polyglotte Ausführung
- **Ressourcen-Monitoring**: Prometheus Metriken

### Multi-Language Support
```python
# Geplant
supported_languages = {
    "python": PythonRunner(),
    "javascript": WasmRunner("js"),
    "rust": WasmRunner("rust"),
    "go": WasmRunner("go")
}
```

## Monitoring

### Health Check
```bash
curl http://exec-sandbox:8600/healthz
```

### Container Logs
```bash
docker logs exec-sandbox
```

### Ressourcen-Überwachung
```bash
docker stats exec-sandbox
```

## Development

### Lokaler Test
```bash
cd services/exec_sandbox
python sandbox_app.py
```

### Docker Build
```bash
docker build -t exec-sandbox .
docker run -p 8600:8600 exec-sandbox
```

### Sicherheits-Test
```python
# Sollte blockiert werden
test_cases = [
    "import os; os.system('ls')",
    "eval('print(\"hacked\")')",
    "__import__('subprocess').call(['ls'])"
]
```

## Hinweise

⚠️ **Warnung**: Diese Implementierung ist ein Demo-Prototyp. Für Produktionsumgebungen sind zusätzliche Sicherheitsmaßnahmen wie gVisor, Firecracker oder WebAssembly-basierte Isolation erforderlich.

🔒 **Sicherheit**: Führen Sie niemals unvertrauenswürdigen Code ohne zusätzliche Container-/VM-Isolation aus.

📊 **Performance**: Ressourcen-Limits sind konservativ gesetzt. Bei Bedarf anpassbar über Umgebungsvariablen.
