#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-safe}"       # safe | aggressive
REPORT_DIR="${REPORT_DIR:-reports/updates}"
mkdir -p "$REPORT_DIR"
TS=$(date -u +%Y%m%dT%H%M%SZ)
REPORT="$REPORT_DIR/update-${TS}.log"
JSON_SUMMARY="$REPORT_DIR/update-summary-${TS}.json"

echo "[INFO] Update run $TS mode=$MODE"
echo "{ \"timestamp\": \"${TS}\", \"mode\": \"${MODE}\", \"sections\": [] }" > "$JSON_SUMMARY"

append_json_section () {
  local SECTION="$1"
  local BODY="$2"
  python3 - <<'PY' "$JSON_SUMMARY" "$SECTION" "$BODY"
import json,sys
f=sys.argv[1]; section=sys.argv[2]; body=sys.argv[3]
doc=json.load(open(f))
doc["sections"].append({"name":section,"body":body})
open(f,"w").write(json.dumps(doc,indent=2))
PY
}

# APT
if command -v apt-get >/dev/null 2>&1; then
  echo "[APT] updating..."
  sudo apt-get update -y >>"$REPORT" 2>&1 || true
  if [ "$MODE" = "aggressive" ]; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get -y dist-upgrade >>"$REPORT" 2>&1 || true
    sudo apt-get -y autoremove --purge >>"$REPORT" 2>&1 || true
    APT_STATUS="upgraded"
  else
    APT_STATUS="refreshed-index"
  fi
  append_json_section "apt" "$APT_STATUS"
fi

# Python
if [ -f requirements.txt ]; then
  BEFORE=$(pip list --outdated --format=freeze 2>/dev/null || true)
  if [ "$MODE" = "aggressive" ]; then
    pip install --upgrade -r requirements.txt >>"$REPORT" 2>&1 || true
  fi
  AFTER=$(pip list --outdated --format=freeze 2>/dev/null || true)
  append_json_section "python" "$(echo -e "before:\n$BEFORE\nafter:\n$AFTER" | sed 's/"//g' | head -c 4000)"
fi

# Node
if [ -f package.json ] && command -v npm >/dev/null 2>&1; then
  OUTDATED=$(npm outdated --json 2>/dev/null || echo "{}")
  if [ "$MODE" = "aggressive" ]; then
    npm update --no-audit --no-fund >>"$REPORT" 2>&1 || true
  fi
  append_json_section "npm" "${OUTDATED:-{}}"
fi

# VS Code Extensions
if command -v code >/dev/null 2>&1; then
  EXT_LIST=$(code --list-extensions | tr '\n' ' ' || true)
  if [ "$MODE" = "aggressive" ]; then
    for e in $EXT_LIST; do 
      code --install-extension "$e" --force >>"$REPORT" 2>&1 || true
    done
  fi
  append_json_section "vscode_extensions" "$EXT_LIST"
fi

# Docker
if docker info >/dev/null 2>&1; then
  COMPOSE_FILES=$(find . -name "docker-compose*.yml" -o -name "compose*.yml" 2>/dev/null | head -5 || true)
  if [ -n "$COMPOSE_FILES" ]; then
    if [ "$MODE" = "aggressive" ]; then
      for f in $COMPOSE_FILES; do 
        docker compose -f "$f" pull >>"$REPORT" 2>&1 || true
      done
      docker image prune -f >>"$REPORT" 2>&1 || true
      append_json_section "docker" "pulled"
    else
      IMAGES=$(docker images --format '{{.Repository}}:{{.Tag}}' | head -c 4000 || true)
      append_json_section "docker" "$IMAGES"
    fi
  fi
fi

# Security quick (optional)
if command -v trivy >/dev/null 2>&1 && [ "$MODE" != "off" ]; then
  trivy fs --security-checks vuln,config --severity HIGH,CRITICAL --exit-code 0 . > "$REPORT_DIR/trivy-${TS}.txt" 2>&1 || true
  append_json_section "trivy" "scan run"
fi

# Test after updates (optional)
if [ -f pyproject.toml ] || [ -f requirements.txt ]; then
  if command -v pytest >/dev/null 2>&1; then
    TEST_RESULT=$(pytest -q --tb=no 2>&1 || echo "TESTS FAILED")
    append_json_section "tests" "$TEST_RESULT"
  fi
fi

echo "[DONE] Summary at $JSON_SUMMARY"
