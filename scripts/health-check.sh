#!/bin/bash
echo "🏥 EU-UNION-AI-PACT Health Check"
echo "==============================="

services=(
    "Gateway:8080:/health"
    "Vault:8200:/v1/sys/health"
    "Code Doctor:8500:/healthz"
    "Data Hub:8400:/healthz"
)

for service_info in "${services[@]}"; do
    IFS=':' read -r name port path <<< "$service_info"
    
    if curl -sf "http://localhost:$port$path" >/dev/null 2>&1; then
        echo "✅ $name - Healthy"
    else
        echo "❌ $name - Not responding"
    fi
done
