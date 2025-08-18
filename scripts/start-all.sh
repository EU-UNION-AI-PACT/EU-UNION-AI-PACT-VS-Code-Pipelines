#!/bin/bash
echo "🚀 Starte EU-UNION-AI-PACT Services..."

# Start Docker services
docker-compose -f docker-compose.simple.yml up -d

# Wait for core services
sleep 10

# Start Python services in background
echo "📡 Starte Gateway..."
./scripts/start-gateway.sh &

echo "🩺 Starte Code Doctor..."
./scripts/start-code-doctor.sh &

echo "🗃️ Starte Data Hub..."
./scripts/start-data-hub.sh &

echo ""
echo "✅ Alle Services gestartet!"
echo ""
echo "🌐 Zugriff über:"
echo "   - Gateway: http://localhost:8080"
echo "   - Vault: http://localhost:8200"
echo "   - Code Doctor: http://localhost:8500"
echo "   - Data Hub: http://localhost:8400"
echo ""
echo "⏹️ Zum Stoppen: ./scripts/stop-all.sh"
