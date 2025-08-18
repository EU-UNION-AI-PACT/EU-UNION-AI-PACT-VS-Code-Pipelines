# Incident Klassifikation

| SEV | Beschreibung | Beispiel |
|-----|--------------|----------|
| SEV1 | Total Outage / Datenverlust | API 0% verfügbar |
| SEV2 | Teilweiser Funktionsverlust / Error Rate >10% | Hohe Fehlerrate Ingest |
| SEV3 | Degradierte Performance (p95 > Ziel) | Langsame Retrievals |
| SEV4 | Minor Glitch / UI Problem | Verzögerte Metrik-Panel |
| SEV5 | Informationshinweis | Geplante Wartung |

Antwortzeiten (MTTA/MTTR):

- SEV1: MTTA < 5m, MTTR < 60m
- SEV2: MTTA < 10m, MTTR < 120m
