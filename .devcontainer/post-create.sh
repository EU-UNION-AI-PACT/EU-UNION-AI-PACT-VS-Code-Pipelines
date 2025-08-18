#!/usr/bin/env bash
set -euo pipefail

echo "[post-create] Installing extra global JS tooling (pnpm, eslint, prettier)..."
corepack prepare pnpm@latest --activate || true

# Example: Install cargo tools (adjust as needed)
TOOLS=(
  "cargo-watch"
  "wasm-pack"
)
for t in "${TOOLS[@]}"; do
  if ! command -v "${t%% *}" >/dev/null 2>&1; then
    cargo install "$t" || echo "Failed to install $t (ignore if transient)"
  fi
done

echo "[post-create] Installing wasmtime..."
if ! command -v wasmtime >/dev/null 2>&1; then
  WT=20.0.0
  curl -sSL "https://github.com/bytecodealliance/wasmtime/releases/download/v${WT}/wasmtime-v${WT}-x86_64-linux.tar.xz" -o /tmp/w.t.xz
  tar -xJf /tmp/w.t.xz -C /tmp
  sudo mv /tmp/wasmtime-v${WT}-x86_64-linux/wasmtime /usr/local/bin/
  rm -rf /tmp/w.t.xz /tmp/wasmtime*
fi

echo "[post-create] Setting up MCP server dependencies..."
if [ -d "services/mcp-server" ]; then
  cd services/mcp-server
  npm ci || npm install
  cd ../..
fi

echo "[post-create] Done."
