#!/usr/bin/env bash
set -euo pipefail
OUT="reports/updates/metrics.prom"
mkdir -p "$(dirname "$OUT")"

LAST=$(ls -t reports/updates 2>/dev/null | grep update-summary | head -n1 || true)
if [ -n "$LAST" ]; then
  TS=$(echo "$LAST" | sed -E 's/.*update-summary-([0-9T]+Z?).*/\1/')
  NOW=$(date -u +%s)
  
  echo "# HELP update_last_run_seconds Unix timestamp of last update summary" > "$OUT"
  echo "# TYPE update_last_run_seconds gauge" >> "$OUT"
  
  # Parse timestamp to epoch
  if command -v date >/dev/null 2>&1; then
    EPOCH=$(date -d "${TS:0:8} ${TS:9:6}" +%s 2>/dev/null || echo "$NOW")
  else
    EPOCH="$NOW"
  fi
  
  echo "update_last_run_seconds $EPOCH" >> "$OUT"
  
  echo "# HELP update_last_mode Last update mode (0=safe, 1=aggressive)" >> "$OUT"
  echo "# TYPE update_last_mode gauge" >> "$OUT"
  
  # Try to extract mode from latest summary
  if [ -f "reports/updates/$LAST" ]; then
    MODE=$(grep -o '"mode": "[^"]*"' "reports/updates/$LAST" | cut -d'"' -f4 || echo "safe")
    if [ "$MODE" = "aggressive" ]; then
      echo "update_last_mode 1" >> "$OUT"
    else
      echo "update_last_mode 0" >> "$OUT"
    fi
  else
    echo "update_last_mode 0" >> "$OUT"
  fi
else
  echo "# No update summaries found" > "$OUT"
fi

echo "Metrics exported to $OUT"
