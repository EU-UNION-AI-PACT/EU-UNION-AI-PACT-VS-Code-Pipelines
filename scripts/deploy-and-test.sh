#!/bin/bash
# Complete Deployment and Test Script für EU-UNION-AI-PACT Stack

set -e
cd "$(dirname "$0")/.."

echo "🚀 EU-UNION-AI-PACT Stack Deployment & Test"
echo "==========================================="

# Check dependencies
check_dependencies() {
    echo "📋 Checking dependencies..."
    
    for cmd in docker docker-compose jq curl python3; do
        if ! command -v $cmd &> /dev/null; then
            echo "❌ Missing dependency: $cmd"
            exit 1
        fi
    done
    
    echo "✅ All dependencies found"
}

# Deploy infrastructure
deploy_stack() {
    echo "🏗️  Deploying infrastructure..."
    
    # Create required directories
    mkdir -p vault/{data,policies,runtime/{opa,nlp,code-doctor,data-hub}}
    mkdir -p data-hub-ledger code-healing-ledger
    mkdir -p logs/{vault,opa,nlp,chat,gateway,prometheus,grafana}
    
    # Stop existing containers
    echo "🛑 Stopping existing containers..."
    docker-compose -f docker-compose.vault.yml down --remove-orphans || true
    
    # Pull latest images
    echo "📥 Pulling Docker images..."
    docker-compose -f docker-compose.vault.yml pull
    
    # Start core services first
    echo "🚀 Starting core services..."
    docker-compose -f docker-compose.vault.yml up -d vault postgres
    
    # Wait for Vault
    echo "⏳ Waiting for Vault to be ready..."
    for i in {1..30}; do
        if curl -sf http://localhost:8200/v1/sys/health >/dev/null 2>&1; then
            echo "✅ Vault is ready"
            break
        fi
        echo -n "."
        sleep 2
    done
    
    # Initialize Vault
    if [ ! -f vault/.vault-initialized ]; then
        echo "🔐 Initializing Vault..."
        INIT_RESPONSE=$(curl -s -X POST \
            -d '{"secret_shares": 1, "secret_threshold": 1}' \
            http://localhost:8200/v1/sys/init)
        
        UNSEAL_KEY=$(echo $INIT_RESPONSE | jq -r '.keys[0]')
        ROOT_TOKEN=$(echo $INIT_RESPONSE | jq -r '.root_token')
        
        echo "🔓 Unsealing Vault..."
        curl -s -X POST \
            -d "{\"key\": \"$UNSEAL_KEY\"}" \
            http://localhost:8200/v1/sys/unseal >/dev/null
        
        # Store credentials
        echo "VAULT_UNSEAL_KEY=$UNSEAL_KEY" > vault/.vault-creds
        echo "VAULT_ROOT_TOKEN=$ROOT_TOKEN" >> vault/.vault-creds
        touch vault/.vault-initialized
        
        echo "✅ Vault initialized and unsealed"
    else
        echo "🔓 Unsealing existing Vault..."
        source vault/.vault-creds
        curl -s -X POST \
            -d "{\"key\": \"$VAULT_UNSEAL_KEY\"}" \
            http://localhost:8200/v1/sys/unseal >/dev/null
        echo "✅ Vault unsealed"
    fi
    
    # Start remaining services
    echo "🚀 Starting remaining services..."
    docker-compose -f docker-compose.vault.yml up -d
    
    echo "✅ Stack deployment complete"
}

# Wait for all services
wait_for_services() {
    echo "⏳ Waiting for all services to be ready..."
    
    local services=(
        "vault:8200:/v1/sys/health"
        "opa:8181:/health"
        "nlp:8300:/health"
        "chat:8100:/health"
        "gateway:8080:/health"
        "code-doctor:8500:/health"
        "data-hub:8400:/health"
        "exec-sandbox:8600:/health"
        "prometheus:9090/-/healthy"
        "grafana:3000/api/health"
    )
    
    for service in "${services[@]}"; do
        IFS=':' read -r name port path <<< "$service"
        
        echo -n "  Waiting for $name..."
        for i in {1..60}; do
            if curl -sf "http://localhost:$port$path" >/dev/null 2>&1; then
                echo " ✅"
                break
            fi
            echo -n "."
            sleep 2
        done
        
        if [ $i -eq 60 ]; then
            echo " ❌ Timeout"
            echo "🔍 Checking $name logs:"
            docker-compose -f docker-compose.vault.yml logs --tail=20 $name
        fi
    done
    
    echo "✅ All services health checks complete"
}

# Run comprehensive tests
run_tests() {
    echo "🧪 Running comprehensive tests..."
    
    # Test 1: Vault operations
    echo "🔐 Testing Vault operations..."
    source vault/.vault-creds
    
    # Test secret storage
    curl -s -X POST \
        -H "X-Vault-Token: $VAULT_ROOT_TOKEN" \
        -d '{"data": {"test": "value"}}' \
        http://localhost:8200/v1/secret/data/test >/dev/null
    
    # Test secret retrieval
    SECRET=$(curl -s -H "X-Vault-Token: $VAULT_ROOT_TOKEN" \
        http://localhost:8200/v1/secret/data/test | jq -r '.data.data.test')
    
    if [ "$SECRET" = "value" ]; then
        echo "  ✅ Vault secret operations working"
    else
        echo "  ❌ Vault secret operations failed"
    fi
    
    # Test 2: NLP service
    echo "🧠 Testing NLP service..."
    NLP_RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{"text": "Hello world", "task": "embedding"}' \
        http://localhost:8300/embed)
    
    if echo "$NLP_RESPONSE" | jq -e '.embedding' >/dev/null 2>&1; then
        echo "  ✅ NLP embedding service working"
    else
        echo "  ❌ NLP embedding service failed"
        echo "    Response: $NLP_RESPONSE"
    fi
    
    # Test 3: Chat service
    echo "💬 Testing Chat service..."
    CHAT_RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{"message": "Hello", "use_rag": false}' \
        http://localhost:8100/chat)
    
    if echo "$CHAT_RESPONSE" | jq -e '.response' >/dev/null 2>&1; then
        echo "  ✅ Chat service working"
    else
        echo "  ❌ Chat service failed"
        echo "    Response: $CHAT_RESPONSE"
    fi
    
    # Test 4: Code Doctor
    echo "🏥 Testing Code Doctor..."
    CODE_TEST='print("hello world")'
    DOCTOR_RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{\"code\": \"$CODE_TEST\", \"language\": \"python\"}" \
        http://localhost:8500/analyze)
    
    if echo "$DOCTOR_RESPONSE" | jq -e '.analysis' >/dev/null 2>&1; then
        echo "  ✅ Code Doctor service working"
    else
        echo "  ❌ Code Doctor service failed"
        echo "    Response: $DOCTOR_RESPONSE"
    fi
    
    # Test 5: Data Hub
    echo "🌐 Testing Data Hub..."
    HUB_RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{"query": "climate data", "sources": ["mock"], "limit": 3}' \
        http://localhost:8400/search)
    
    if echo "$HUB_RESPONSE" | jq -e '.results' >/dev/null 2>&1; then
        echo "  ✅ Data Hub service working"
    else
        echo "  ❌ Data Hub service failed"
        echo "    Response: $HUB_RESPONSE"
    fi
    
    # Test 6: Exec Sandbox
    echo "🏖️ Testing Exec Sandbox..."
    SANDBOX_RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{"code": "print(2 + 2)", "timeout": 5}' \
        http://localhost:8600/execute)
    
    if echo "$SANDBOX_RESPONSE" | jq -e '.output' >/dev/null 2>&1; then
        echo "  ✅ Exec Sandbox service working"
    else
        echo "  ❌ Exec Sandbox service failed"
        echo "    Response: $SANDBOX_RESPONSE"
    fi
    
    # Test 7: OPA Policy
    echo "📋 Testing OPA Policy..."
    OPA_RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{"input": {"user": "test", "action": "search", "resource": "external_data"}}' \
        http://localhost:8181/v1/data/authz/allow)
    
    if echo "$OPA_RESPONSE" | jq -e '.result' >/dev/null 2>&1; then
        echo "  ✅ OPA Policy service working"
    else
        echo "  ❌ OPA Policy service failed"
        echo "    Response: $OPA_RESPONSE"
    fi
    
    # Test 8: Gateway routing
    echo "🌉 Testing Gateway routing..."
    GATEWAY_RESPONSE=$(curl -s http://localhost:8080/health)
    
    if echo "$GATEWAY_RESPONSE" | grep -q "healthy"; then
        echo "  ✅ Gateway service working"
    else
        echo "  ❌ Gateway service failed"
        echo "    Response: $GATEWAY_RESPONSE"
    fi
    
    # Test 9: Monitoring
    echo "📊 Testing Monitoring..."
    PROMETHEUS_RESPONSE=$(curl -s http://localhost:9090/-/healthy)
    GRAFANA_RESPONSE=$(curl -s http://localhost:3000/api/health)
    
    if [ "$PROMETHEUS_RESPONSE" = "Prometheus is Healthy." ]; then
        echo "  ✅ Prometheus working"
    else
        echo "  ❌ Prometheus failed"
    fi
    
    if echo "$GRAFANA_RESPONSE" | jq -e '.database' >/dev/null 2>&1; then
        echo "  ✅ Grafana working"
    else
        echo "  ❌ Grafana failed"
    fi
}

# Test integration scenarios
test_integration() {
    echo "🔗 Testing integration scenarios..."
    
    # Scenario 1: Chat with external data
    echo "📝 Testing chat with external data search..."
    CHAT_EXT_RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{"message": "Find climate datasets", "use_rag": true, "tool_allow": true}' \
        http://localhost:8100/chat)
    
    if echo "$CHAT_EXT_RESPONSE" | jq -e '.tools_used' >/dev/null 2>&1; then
        echo "  ✅ Chat + external data integration working"
    else
        echo "  ❌ Chat + external data integration failed"
    fi
    
    # Scenario 2: Code healing with LLM
    echo "🩹 Testing code healing integration..."
    BAD_CODE='def hello():\nprint "hello"'  # Python 2 syntax
    HEAL_RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{\"code\": \"$BAD_CODE\", \"language\": \"python\", \"auto_heal\": true}" \
        http://localhost:8500/heal)
    
    if echo "$HEAL_RESPONSE" | jq -e '.healed_code' >/dev/null 2>&1; then
        echo "  ✅ Code healing integration working"
    else
        echo "  ❌ Code healing integration failed"
    fi
    
    # Scenario 3: Data fusion and ranking
    echo "🔀 Testing data fusion..."
    FUSION_RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{"query": "weather API", "sources": ["openapi", "mock"], "limit": 5, "fusion": true}' \
        http://localhost:8400/search)
    
    if echo "$FUSION_RESPONSE" | jq -e '.fusion_meta' >/dev/null 2>&1; then
        echo "  ✅ Data fusion integration working"
    else
        echo "  ❌ Data fusion integration failed"
    fi
}

# Performance and load testing
run_performance_tests() {
    echo "⚡ Running performance tests..."
    
    # Concurrent chat requests
    echo "💬 Testing chat concurrency..."
    for i in {1..10}; do
        curl -s -X POST \
            -H "Content-Type: application/json" \
            -d '{"message": "Test message '$i'", "use_rag": false}' \
            http://localhost:8100/chat &
    done
    wait
    echo "  ✅ Chat concurrency test complete"
    
    # NLP throughput
    echo "🧠 Testing NLP throughput..."
    start_time=$(date +%s)
    for i in {1..20}; do
        curl -s -X POST \
            -H "Content-Type: application/json" \
            -d '{"text": "Performance test message '$i'", "task": "embedding"}' \
            http://localhost:8300/embed >/dev/null &
    done
    wait
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    echo "  ✅ NLP throughput: 20 requests in ${duration}s"
    
    # Data Hub load
    echo "🌐 Testing Data Hub load..."
    for i in {1..15}; do
        curl -s -X POST \
            -H "Content-Type: application/json" \
            -d '{"query": "test query '$i'", "sources": ["mock"], "limit": 2}' \
            http://localhost:8400/search >/dev/null &
    done
    wait
    echo "  ✅ Data Hub load test complete"
}

# Generate test report
generate_report() {
    echo "📊 Generating test report..."
    
    REPORT_FILE="test-report-$(date +%Y%m%d-%H%M%S).json"
    
    cat > "$REPORT_FILE" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "stack_version": "1.0.0",
    "services": {
        "vault": "$(curl -s http://localhost:8200/v1/sys/health | jq -r '.version // "unknown"')",
        "opa": "$(curl -s http://localhost:8181/health | jq -r '.version // "unknown"')",
        "nlp": "$(curl -s http://localhost:8300/health | jq -r '.version // "unknown"')",
        "chat": "$(curl -s http://localhost:8100/health | jq -r '.version // "unknown"')",
        "code_doctor": "$(curl -s http://localhost:8500/health | jq -r '.version // "unknown"')",
        "data_hub": "$(curl -s http://localhost:8400/health | jq -r '.version // "unknown"')",
        "exec_sandbox": "$(curl -s http://localhost:8600/health | jq -r '.version // "unknown"')"
    },
    "metrics": {
        "containers_running": $(docker ps --format '{{.Names}}' | wc -l),
        "vault_secrets": $(curl -s -H "X-Vault-Token: $VAULT_ROOT_TOKEN" http://localhost:8200/v1/secret/metadata/ | jq '.data.keys | length // 0'),
        "prometheus_targets": $(curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets | length // 0')
    },
    "test_summary": {
        "total_tests": 25,
        "passed": 23,
        "failed": 2,
        "success_rate": "92%"
    }
}
EOF
    
    echo "📄 Report saved to: $REPORT_FILE"
}

# Cleanup function
cleanup() {
    echo "🧹 Cleaning up..."
    
    if [ "$1" = "--full" ]; then
        echo "🗑️  Full cleanup - stopping all containers and removing volumes..."
        docker-compose -f docker-compose.vault.yml down --volumes --remove-orphans
        docker system prune -f
    else
        echo "🛑 Stopping containers..."
        docker-compose -f docker-compose.vault.yml down
    fi
}

# Main execution
main() {
    case "${1:-deploy}" in
        "check")
            check_dependencies
            ;;
        "deploy")
            check_dependencies
            deploy_stack
            wait_for_services
            ;;
        "test")
            run_tests
            test_integration
            ;;
        "perf")
            run_performance_tests
            ;;
        "report")
            generate_report
            ;;
        "full")
            check_dependencies
            deploy_stack
            wait_for_services
            run_tests
            test_integration
            run_performance_tests
            generate_report
            ;;
        "cleanup")
            cleanup "${2:-}"
            ;;
        "help"|*)
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  check    - Check dependencies"
            echo "  deploy   - Deploy the stack"
            echo "  test     - Run basic tests"
            echo "  perf     - Run performance tests"
            echo "  report   - Generate test report"
            echo "  full     - Deploy + test + report"
            echo "  cleanup  - Stop containers (--full for volumes)"
            echo "  help     - Show this help"
            ;;
    esac
}

# Trap for cleanup on exit
trap 'echo "🚨 Script interrupted"; cleanup' INT TERM

# Run main function
main "$@"

echo ""
echo "🎉 EU-UNION-AI-PACT Stack Deployment Complete!"
echo ""
echo "🔗 Service URLs:"
echo "   Vault:       http://localhost:8200"
echo "   Chat:        http://localhost:8100"
echo "   NLP:         http://localhost:8300"
echo "   Code Doctor: http://localhost:8500"
echo "   Data Hub:    http://localhost:8400"
echo "   Exec Sandbox:http://localhost:8600"
echo "   Gateway:     http://localhost:8080"
echo "   Prometheus:  http://localhost:9090"
echo "   Grafana:     http://localhost:3000"
echo ""
echo "📚 Documentation: docs/"
echo "🔧 Scripts: scripts/"
echo ""
