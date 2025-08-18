#!/bin/bash
# Invisible Hosting Test Suite
# Test all invisible hosting methods

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

echo "🧪 Invisible Hosting Test Suite"
echo "================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

test_result() {
    local test_name="$1"
    local success="$2"
    local message="$3"
    
    if [ "$success" = "true" ]; then
        echo -e "${GREEN}✅ PASS${NC}: $test_name"
        [ -n "$message" ] && echo "   💡 $message"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}❌ FAIL${NC}: $test_name"
        [ -n "$message" ] && echo "   ❌ $message"
        ((TESTS_FAILED++))
    fi
}

# Test 1: Check dependencies
echo -e "\n${BLUE}📋 Testing Dependencies${NC}"

check_command() {
    local cmd="$1"
    local name="$2"
    
    if command -v "$cmd" &> /dev/null; then
        test_result "$name available" "true" "$(which $cmd)"
    else
        test_result "$name available" "false" "Please install $name"
    fi
}

check_command "docker" "Docker"
check_command "docker-compose" "Docker Compose"
check_command "curl" "curl"
check_command "dig" "dig (DNS lookup)"
check_command "python3" "Python 3"

# Test 2: File structure
echo -e "\n${BLUE}📁 Testing File Structure${NC}"

check_file() {
    local file="$1"
    local name="$2"
    
    if [ -f "$file" ]; then
        test_result "$name exists" "true" "$file"
    else
        test_result "$name exists" "false" "Missing: $file"
    fi
}

check_file "scripts/setup-cloudflare-tunnel.sh" "Cloudflare tunnel script"
check_file "scripts/setup-nip-io.sh" "nip.io setup script"
check_file "scripts/registry.py" "Registry service"
check_file "services/trailstar_api/app.py" "Flask API"
check_file "services/trailstar_api/src/main.rs" "Rust API"

# Test 3: Script permissions
echo -e "\n${BLUE}🔐 Testing Script Permissions${NC}"

check_executable() {
    local file="$1"
    local name="$2"
    
    if [ -x "$file" ]; then
        test_result "$name executable" "true"
    else
        test_result "$name executable" "false" "Run: chmod +x $file"
    fi
}

check_executable "scripts/setup-cloudflare-tunnel.sh" "Cloudflare script"
check_executable "scripts/setup-nip-io.sh" "nip.io script"
check_executable "scripts/registry.py" "Registry script"

# Test 4: Python dependencies
echo -e "\n${BLUE}🐍 Testing Python Dependencies${NC}"

test_python_import() {
    local module="$1"
    local name="$2"
    
    if python3 -c "import $module" 2>/dev/null; then
        test_result "$name import" "true"
    else
        test_result "$name import" "false" "Run: pip3 install $module"
    fi
}

test_python_import "flask" "Flask"
test_python_import "requests" "Requests"

# Test 5: Network connectivity
echo -e "\n${BLUE}🌐 Testing Network Connectivity${NC}"

test_network() {
    local host="$1"
    local name="$2"
    
    if curl -s --max-time 5 "$host" >/dev/null 2>&1; then
        test_result "$name connectivity" "true"
    else
        test_result "$name connectivity" "false" "Cannot reach $host"
    fi
}

test_network "https://api.cloudflare.com" "Cloudflare API"
test_network "https://8.8.8.8.nip.io" "nip.io service"

# Test 6: Public IP detection
echo -e "\n${BLUE}📍 Testing Public IP Detection${NC}"

detect_public_ip() {
    local ip
    ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || curl -s --max-time 5 ipinfo.io/ip 2>/dev/null || echo "")
    
    if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        test_result "Public IP detection" "true" "IP: $ip"
        echo "$ip" > /tmp/detected_ip.txt
    else
        test_result "Public IP detection" "false" "Could not detect valid IP"
    fi
}

detect_public_ip

# Test 7: nip.io DNS resolution
echo -e "\n${BLUE}🔍 Testing nip.io DNS Resolution${NC}"

if [ -f "/tmp/detected_ip.txt" ]; then
    IP=$(cat /tmp/detected_ip.txt)
    IP_DASHED=$(echo "$IP" | tr '.' '-')
    DOMAIN="$IP_DASHED.nip.io"
    
    RESOLVED_IP=$(dig +short "$DOMAIN" @8.8.8.8 2>/dev/null || echo "")
    
    if [ "$RESOLVED_IP" = "$IP" ]; then
        test_result "nip.io DNS resolution" "true" "$DOMAIN -> $IP"
    else
        test_result "nip.io DNS resolution" "false" "$DOMAIN -> $RESOLVED_IP (expected: $IP)"
    fi
else
    test_result "nip.io DNS resolution" "false" "No IP detected"
fi

# Test 8: Registry service
echo -e "\n${BLUE}📝 Testing Registry Service${NC}"

test_registry() {
    if python3 scripts/registry.py list >/dev/null 2>&1; then
        test_result "Registry service basic" "true"
        
        # Test registration
        if python3 scripts/registry.py register test "http://localhost:8000" static >/dev/null 2>&1; then
            test_result "Registry registration" "true"
            
            # Test retrieval
            if python3 scripts/registry.py get test >/dev/null 2>&1; then
                test_result "Registry retrieval" "true"
            else
                test_result "Registry retrieval" "false"
            fi
            
            # Cleanup
            python3 scripts/registry.py remove test >/dev/null 2>&1
        else
            test_result "Registry registration" "false"
        fi
    else
        test_result "Registry service basic" "false"
    fi
}

test_registry

# Test 9: Docker setup
echo -e "\n${BLUE}🐳 Testing Docker Setup${NC}"

if docker info >/dev/null 2>&1; then
    test_result "Docker daemon" "true"
    
    # Test compose files exist
    if [ -f "docker-compose.yml" ]; then
        test_result "Docker Compose main file" "true"
    else
        test_result "Docker Compose main file" "false"
    fi
    
else
    test_result "Docker daemon" "false" "Docker daemon not running"
fi

# Test 10: Port availability
echo -e "\n${BLUE}🔌 Testing Port Availability${NC}"

test_port() {
    local port="$1"
    local name="$2"
    
    if ! netstat -tuln 2>/dev/null | grep -q ":$port "; then
        test_result "Port $port ($name)" "true" "Available"
    else
        test_result "Port $port ($name)" "false" "Already in use"
    fi
}

test_port 8000 "Main API"
test_port 8100 "Secondary API"
test_port 80 "HTTP"
test_port 443 "HTTPS"

# Summary
echo -e "\n${BLUE}📊 Test Summary${NC}"
echo "=============="
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}🎉 All tests passed! System ready for invisible hosting.${NC}"
    
    echo -e "\n${YELLOW}💡 Next Steps:${NC}"
    echo "1. Choose your hosting method:"
    echo "   - Cloudflare Tunnel: ./scripts/setup-cloudflare-tunnel.sh"
    echo "   - nip.io: ./scripts/setup-nip-io.sh"
    echo "2. Start services: docker-compose up -d"
    echo "3. Test: curl <your-url>/health"
    
    exit 0
else
    echo -e "\n${RED}❌ Some tests failed. Please fix the issues above.${NC}"
    exit 1
fi
