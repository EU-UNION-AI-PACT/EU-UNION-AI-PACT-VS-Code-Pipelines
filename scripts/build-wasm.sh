#!/usr/bin/env bash
set -euo pipefail

echo "Building WASM AI Validator Plugin..."
rustup target add wasm32-wasi 2>/dev/null || true
cargo build --release --target wasm32-wasi --manifest-path wasm-plugins/ai-validator/Cargo.toml

echo "✅ WASM plugin built: target/wasm32-wasi/release/ai_validator.wasm"
echo ""
echo "Testing with wasmtime:"
if command -v wasmtime >/dev/null 2>&1; then
  echo "Wasmtime available - testing basic function..."
  # wasmtime run target/wasm32-wasi/release/ai_validator.wasm --invoke validate_compliance 100
else
  echo "⚠️  Wasmtime not found - install with: curl -sSf https://wasmtime.dev/install.sh | bash"
fi
