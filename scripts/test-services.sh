#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${1:-http://localhost}"
echo "Testing EU AI Pact services at: $BASE_URL"
echo "================================================"

echo "🔍 Testing MCP Server..."
echo "Health check:"
curl -sSf "$BASE_URL/mcp/healthz" | jq . || echo "❌ MCP health check failed"

echo -e "\nAvailable tools:"
curl -sSf "$BASE_URL/mcp/tools" | jq . || echo "❌ MCP tools endpoint failed"

echo -e "\nTesting AI compliance validation:"
curl -sSf -X POST "$BASE_URL/mcp/invoke" \
  -H "Content-Type: application/json" \
  -d '{"tool":"validate-ai-compliance","args":{"system":"Test AI System"}}' | \
  jq . || echo "❌ AI compliance validation failed"

echo -e "\n⚡ Testing WASM Validator..."
curl -sSf -X POST "$BASE_URL/validate/validate" \
  -H "Content-Type: application/json" \
  -d '{"validator":"ai-validator","payload":{"aiSystem":"TestSystem","documentation":"comprehensive"}}' | \
  jq . || echo "❌ WASM validation failed"

echo -e "\n✅ Testing completed!"
