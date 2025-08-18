#!/usr/bin/env bash
# Beispiel: Batch Hash + optional minisign (falls installiert)
set -euo pipefail
LEDGER=nlp/storage/ledger/ledger.jsonl
if [ ! -f "$LEDGER" ]; then
  echo "Ledger fehlt"; exit 1
fi
TS=$(date -u +%Y%m%dT%H%M%SZ)
BATCH_HASH=$(sha256sum "$LEDGER" | awk '{print $1}')
echo "$TS $BATCH_HASH" >> nlp/storage/ledger/batch_hashes.log
if command -v minisign >/dev/null 2>&1; then
  minisign -Sm nlp/storage/ledger/batch_hashes.log || echo "Minisign fehlgeschlagen"
fi
echo "Batch Hash protokolliert: $BATCH_HASH"
