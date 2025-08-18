#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Starting Data Hub Integration Test..."

# Build and start services
echo "📦 Building Data Hub services..."
docker-compose -f docker-compose.vault.yml build data-hub exec-sandbox

echo "🏃 Starting services..."
docker-compose -f docker-compose.vault.yml up -d data-hub exec-sandbox

# Wait for services to be ready
echo "⏳ Waiting for services..."
for i in {1..30}; do
    if curl -sf http://localhost:8400/healthz >/dev/null 2>&1 && \
       curl -sf http://localhost:8600/healthz >/dev/null 2>&1; then
        echo "✅ Services ready!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ Services failed to start"
        exit 1
    fi
    sleep 2
done

echo ""
echo "🔍 Testing Data Hub endpoints..."

# Test unified search
echo "📊 Testing unified search (CKAN + SPARQL + OpenAPI)..."
curl -s "http://localhost:8400/search/unified?q=climate&limit=3" | jq '.total, .sources'

echo ""
echo "🌐 Testing open data search..."
curl -s "http://localhost:8400/search/opendata?q=weather&limit=2" | jq '.total'

echo ""
echo "🔧 Testing OpenAPI search..."
curl -s "http://localhost:8400/search/openapi?q=user&limit=2" | jq '.total'

echo ""
echo "⚡ Testing sandbox execution..."
SANDBOX_RESULT=$(curl -s -X POST http://localhost:8600/run \
  -H "Content-Type: application/json" \
  -d '{
    "language": "python",
    "code": "print(\"Hello from sandbox!\"); result = 2 + 2; print(f\"2 + 2 = {result}\")"
  }')

echo "Sandbox result:" 
echo "$SANDBOX_RESULT" | jq '.'

# Test data hub proxy to sandbox
echo ""
echo "🔄 Testing Data Hub → Sandbox proxy..."
PROXY_RESULT=$(curl -s -X POST http://localhost:8400/sandbox/run \
  -H "Content-Type: application/json" \
  -d '{
    "language": "python", 
    "code": "import math; print(f\"π ≈ {math.pi:.4f}\")"
  }')

echo "Proxy result:"
echo "$PROXY_RESULT" | jq '.'

echo ""
echo "📈 Testing meta endpoints..."
curl -s http://localhost:8400/meta/sources | jq '.ckan_bases | length'

echo ""
echo "🧹 Testing cache flush..."
curl -s -X POST http://localhost:8400/cache/flush | jq '.status'

echo ""
echo "✨ Integration test completed successfully!"
echo ""
echo "🌐 Available endpoints:"
echo "  - Data Hub: http://localhost:8400"
echo "  - Sandbox: http://localhost:8600" 
echo "  - Health: http://localhost:8400/healthz"
echo ""
echo "📖 Try some queries:"
echo "  curl \"http://localhost:8400/search/unified?q=energy&limit=5\""
echo "  curl \"http://localhost:8400/search/opendata?q=transport&limit=3\""
