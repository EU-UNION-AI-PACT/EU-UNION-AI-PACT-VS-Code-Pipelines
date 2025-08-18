#!/usr/bin/env bash
set -euo pipefail
MODE="${AUTO_UPDATE_MODE:-safe}"  # safe | aggressive | off
LOG_DIR="${WORKSPACE_FOLDER:-/workspaces}/.auto-update/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/start-$(date -u +%Y%m%dT%H%M%SZ).log"

{
  echo "[INFO] Auto-Update start $(date -u +%Y-%m-%dT%H:%M:%SZ) mode=$MODE"

  if [ "$MODE" = "off" ]; then
    echo "[INFO] Skipping auto updates (MODE=off)."
    exit 0
  fi

  if command -v apt-get >/dev/null 2>&1; then
    echo "[STEP] apt update (no upgrade in safe mode)"
    sudo apt-get update -y
    if [ "$MODE" = "aggressive" ]; then
      sudo DEBIAN_FRONTEND=noninteractive apt-get -y dist-upgrade
      sudo apt-get -y autoremove --purge
    fi
  fi

  if [ -f requirements.txt ]; then
    echo "[STEP] Python deps (requirements.txt)"
    pip install --upgrade pip setuptools wheel
    if [ "$MODE" = "aggressive" ]; then
      pip install -r requirements.txt --upgrade
    else
      pip list --outdated
    fi
  elif [ -f pyproject.toml ]; then
    echo "[STEP] Python (pyproject)"
    pip install --upgrade pip setuptools wheel
    if [ "$MODE" = "aggressive" ]; then
      pip install . --upgrade
    fi
  fi

  if [ -f package.json ]; then
    if command -v npm >/dev/null 2>&1; then
      echo "[STEP] npm outdated"
      npm install -g npm@latest || true
      if [ "$MODE" = "aggressive" ]; then
        npm update --no-audit --no-fund
      else
        npm outdated || true
      fi
    fi
  fi

  if command -v code >/dev/null 2>&1; then
    echo "[STEP] VS Code extensions refresh"
    code --list-extensions | while read -r ext; do
      if [ "$MODE" = "aggressive" ]; then
        code --install-extension "$ext" --force || true
      fi
    done
  fi

  if docker info >/dev/null 2>&1; then
    echo "[STEP] Docker image pulls (safe=list only)"
    if [ "$MODE" = "aggressive" ]; then
      docker compose pull || true
      docker image prune -f || true
    else
      docker images --format '{{.Repository}}:{{.Tag}}'
    fi
  fi

  echo "[DONE] Auto-update sequence complete."
} | tee "$LOG_FILE"
