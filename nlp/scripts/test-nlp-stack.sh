#!/usr/bin/env bash
# Test script for NLP/IP Protection Stack
set -euo pipefail

echo "🧪 Testing NLP/IP Protection Stack..."

# Check if services are running
echo "📡 Checking service health..."

services=(
  "http://localhost:5432"  # PostgreSQL (via pg_isready would be better)
  "http://localhost:8000/healthz"  # Embedding service  
  "http://localhost:8100/healthz"  # Document processor
  "http://localhost:8200/healthz"  # IP Guard
  "http://localhost:8181/health"   # OPA
  "http://localhost:8080/healthz"  # Gateway
)

for service in "${services[@]}"; do
  if curl -sf "$service" >/dev/null 2>&1; then
    echo "✅ $service - OK"
  else
    echo "❌ $service - FAILED"
  fi
done

# Test OPA Policy
echo ""
echo "🔐 Testing OPA Policy..."
response=$(curl -s -X POST http://localhost:8181/v1/data/nlp/allow \
  -H "Content-Type: application/json" \
  -d '{"input":{"action":"ingest","classification":"internal","user_roles":["data-steward"]}}' || echo "FAILED")

if echo "$response" | grep -q '"result":true'; then
  echo "✅ OPA Policy - Data Steward can ingest internal documents"
else
  echo "❌ OPA Policy test failed: $response"
fi

# Test document ingestion (if test file exists)
if [ -f "test-document.txt" ]; then
  echo ""
  echo "📄 Testing document ingestion..."
  response=$(curl -s -F file=@test-document.txt http://localhost:8100/ingest || echo "FAILED")
  if echo "$response" | grep -q '"doc_id"'; then
    echo "✅ Document ingestion successful"
    doc_id=$(echo "$response" | grep -o '"doc_id":"[^"]*"' | cut -d'"' -f4)
    echo "   Document ID: $doc_id"
  else
    echo "❌ Document ingestion failed: $response"
  fi
else
  echo "⚠️  No test-document.txt found, skipping document ingestion test"
  echo "   Create a test file: echo 'Test document content' > test-document.txt"
fi

echo ""
echo "🔍 Testing IP Guard verification..."
# Test hash verification with a known hash
test_hash="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"  # empty string SHA256
response=$(curl -s -X POST http://localhost:8200/verify \
  -H "Content-Type: application/json" \
  -d "{\"hash_hex\":\"$test_hash\"}" || echo "FAILED")

if echo "$response" | grep -q '"present"'; then
  echo "✅ Hash verification endpoint working"
else
  echo "❌ Hash verification failed: $response"
fi

echo ""
echo "🧪 NLP/IP Stack test completed!"
echo ""
echo "📋 Quick Start Commands:"
echo "   • Start stack: docker compose -f docker-compose.nlp.yml --env-file .env.nlp up"
echo "   • Upload doc:  curl -F file=@your-doc.txt http://localhost:8100/ingest"
echo "   • Test policy: curl -X POST http://localhost:8181/v1/data/nlp/allow -d '{...}'"
echo "   • Check logs:  docker compose -f docker-compose.nlp.yml logs"
