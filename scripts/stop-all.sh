#!/bin/bash
echo "⏹️ Stoppe alle Services..."

# Stop Python processes
pkill -f "python.*main.py" || true

# Stop Docker services
docker-compose -f docker-compose.simple.yml down

echo "✅ Alle Services gestoppt"
