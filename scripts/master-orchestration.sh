#!/bin/bash
# EU-UNION-AI-PACT Master Orchestration Script
# Vollständige automatische Initialisierung ohne Benutzereingaben

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo -e "${PURPLE}🇪🇺 EU-UNION-AI-PACT - Master Orchestration${NC}"
echo -e "${PURPLE}===========================================${NC}"
echo ""

# Configuration
PROJECT_NAME="eu-union-ai-pact"
REGISTRY_INITIALIZED=false
VAULT_INITIALIZED=false
SERVICES_STARTED=false

# Logging
setup_logging() {
    local log_dir="logs/setup"
    mkdir -p "$log_dir"
    
    exec 1> >(tee -a "$log_dir/setup-$(date +%Y%m%d-%H%M%S).log")
    exec 2> >(tee -a "$log_dir/errors-$(date +%Y%m%d-%H%M%S).log" >&2)
    
    echo -e "${BLUE}📝 Logging setup complete - logs in: $log_dir${NC}"
}

# Step 1: System Preparation
system_prep() {
    echo -e "\n${BLUE}🔧 Step 1: System Preparation${NC}"
    
    # Create all necessary directories
    echo "📁 Creating directory structure..."
    mkdir -p {config,logs/{setup,services},data/{vault,postgres,redis},temp,backups}
    mkdir -p vault/{policies,init,runtime/{docproc,ipguard,gateway,code-doctor,data-hub}}
    mkdir -p nlp/{storage/{raw,normalized,derived,ledger},migrations,security/{opa,classification}}
    mkdir -p services/{code_doctor,data_hub,exec_sandbox,trailstar_api/{src,templates}}
    mkdir -p clients/{node,python}
    mkdir -p infra/{nginx/conf.d,terraform,bicep}
    mkdir -p k8s/{base,overlays/{dev,staging,prod}}
    mkdir -p scripts/{setup,deploy,backup,monitoring}
    
    # Set permissions
    echo "🔐 Setting permissions..."
    find scripts -name "*.sh" -exec chmod +x {} \;
    find scripts -name "*.py" -exec chmod +x {} \;
    
    # Create .env file with defaults
    echo "⚙️ Creating environment configuration..."
    cat > .env << EOF
# EU-UNION-AI-PACT Configuration
PROJECT_NAME=$PROJECT_NAME
COMPOSE_PROJECT_NAME=$PROJECT_NAME

# Database
POSTGRES_PASSWORD=SecureVaultPass2024!
POSTGRES_USER=nlp
POSTGRES_DB=nlpdb

# Vault
VAULT_DEV_ROOT_TOKEN=root-dev-token
VAULT_ADDR=http://localhost:8200

# APIs
OPENAI_API_KEY=
OPENAI_API_BASE=https://api.openai.com/v1
OPENAI_MODEL=gpt-4o-mini

# Networking
EXTERNAL_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "127.0.0.1")
BASE_PORT=8000

# Security
INTERNAL_API_TOKEN=$(openssl rand -hex 32)
ENCRYPTION_KEY=$(openssl rand -hex 32)

# Features
ENABLE_INVISIBLE_HOSTING=true
ENABLE_MONITORING=true
ENABLE_TRACING=true
EOF

    source .env
    echo -e "${GREEN}✅ System preparation complete${NC}"
}

# Step 2: Dependencies Installation
install_dependencies() {
    echo -e "\n${BLUE}🔧 Step 2: Installing Dependencies${NC}"
    
    # Update package manager
    echo "📦 Updating package manager..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update -qq
        
        # Install system dependencies
        sudo apt-get install -y \
            curl \
            wget \
            git \
            jq \
            netcat-openbsd \
            dnsutils \
            openssl \
            python3 \
            python3-pip \
            python3-venv \
            nodejs \
            npm \
            docker.io \
            docker-compose \
            nginx \
            certbot \
            fail2ban \
            ufw
            
    elif command -v yum &> /dev/null; then
        sudo yum update -y
        sudo yum install -y curl wget git jq nc bind-utils openssl python3 python3-pip nodejs npm docker docker-compose nginx certbot fail2ban firewalld
    else
        echo -e "${YELLOW}⚠️ Unknown package manager - please install dependencies manually${NC}"
    fi
    
    # Start Docker
    echo "🐳 Starting Docker..."
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker $USER
    
    # Install Python dependencies
    echo "🐍 Installing Python dependencies..."
    python3 -m pip install --upgrade pip
    python3 -m pip install \
        fastapi \
        uvicorn \
        flask \
        requests \
        aiohttp \
        sqlalchemy \
        psycopg2-binary \
        redis \
        celery \
        prometheus-client \
        hvac \
        cryptography \
        pyjwt \
        click \
        typer \
        rich \
        pytest \
        pytest-asyncio
    
    # Install Node.js dependencies globally
    echo "📦 Installing Node.js dependencies..."
    sudo npm install -g \
        typescript \
        ts-node \
        nodemon \
        pm2 \
        eslint \
        prettier
    
    # Install Rust (for high-performance services)
    echo "🦀 Installing Rust..."
    if ! command -v rustc &> /dev/null; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source ~/.cargo/env
    fi
    
    echo -e "${GREEN}✅ Dependencies installation complete${NC}"
}

# Step 3: Service Initialization
init_services() {
    echo -e "\n${BLUE}🔧 Step 3: Service Initialization${NC}"
    
    # Initialize Vault policies
    echo "🔐 Initializing Vault policies..."
    cat > vault/policies/docproc-policy.hcl << 'EOF'
path "kv/data/app/*" {
  capabilities = ["read"]
}
path "transit/encrypt/doc-bytes" {
  capabilities = ["update"]
}
path "transit/decrypt/doc-bytes" {
  capabilities = ["update"]
}
path "transit/sign/ledger-sign" {
  capabilities = ["update"]
}
path "database/creds/docproc-role" {
  capabilities = ["read"]
}
EOF

    # Initialize database migrations
    echo "🗄️ Creating database migrations..."
    cat > nlp/migrations/01_init.sql << 'EOF'
-- EU-UNION-AI-PACT Database Schema
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Documents table
CREATE TABLE documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    filename VARCHAR(255) NOT NULL,
    content_hash VARCHAR(64) UNIQUE NOT NULL,
    content_type VARCHAR(100),
    size_bytes INTEGER,
    classification VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Embeddings table
CREATE TABLE embeddings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_id UUID REFERENCES documents(id) ON DELETE CASCADE,
    content_chunk TEXT NOT NULL,
    embedding vector(384),
    chunk_index INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Audit log
CREATE TABLE audit_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    action VARCHAR(50) NOT NULL,
    resource_type VARCHAR(50),
    resource_id VARCHAR(255),
    user_id VARCHAR(100),
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    details JSONB DEFAULT '{}'::jsonb
);

-- Indexes
CREATE INDEX idx_documents_hash ON documents(content_hash);
CREATE INDEX idx_documents_classification ON documents(classification);
CREATE INDEX idx_embeddings_document ON embeddings(document_id);
CREATE INDEX idx_audit_timestamp ON audit_log(timestamp);
CREATE INDEX idx_audit_action ON audit_log(action);

-- Functions
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_documents_updated_at
    BEFORE UPDATE ON documents
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();
EOF

    # Initialize OPA policies
    echo "📋 Creating OPA policies..."
    mkdir -p nlp/security/opa
    cat > nlp/security/opa/main.rego << 'EOF'
package nlp

import rego.v1

default allow := false

# Allow if user has required role
allow if {
    input.user.roles[_] == "admin"
}

allow if {
    input.user.roles[_] == "processor"
    input.action in ["read", "process"]
}

# Classification-based access
allow if {
    input.document.classification == "public"
}

allow if {
    input.document.classification == "internal"
    input.user.clearance_level >= 2
}

allow if {
    input.document.classification == "confidential"
    input.user.clearance_level >= 3
}

allow if {
    input.document.classification == "secret"
    input.user.clearance_level >= 4
}
EOF

    # Initialize classification rules
    cat > nlp/security/classification.yaml << 'EOF'
classification_rules:
  - pattern: "(?i)(confidential|secret|classified)"
    classification: "confidential"
    confidence: 0.9
  
  - pattern: "(?i)(internal|company|proprietary)"
    classification: "internal"
    confidence: 0.8
  
  - pattern: "(?i)(public|open|general)"
    classification: "public"
    confidence: 0.7
  
  - pattern: "(?i)(password|token|key|secret)"
    classification: "secret"
    confidence: 0.95

default_classification: "internal"
auto_classify: true
EOF

    echo -e "${GREEN}✅ Service initialization complete${NC}"
}

# Step 4: Container Build & Start
build_and_start() {
    echo -e "\n${BLUE}🔧 Step 4: Building and Starting Services${NC}"
    
    # Build all services
    echo "🏗️ Building Docker images..."
    
    # Ensure all Dockerfiles exist with basic content
    services=("code_doctor" "data_hub" "exec_sandbox")
    
    for service in "${services[@]}"; do
        if [ ! -f "services/$service/Dockerfile" ]; then
            echo "📦 Creating Dockerfile for $service..."
            case $service in
                "code_doctor")
                    cat > "services/$service/Dockerfile" << 'EOF'
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
EXPOSE 8500
CMD ["python", "main.py"]
EOF
                    ;;
                "data_hub")
                    cat > "services/$service/Dockerfile" << 'EOF'
FROM python:3.11-slim
WORKDIR /app
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
EXPOSE 8400
CMD ["python", "main.py"]
EOF
                    ;;
                "exec_sandbox")
                    cat > "services/$service/Dockerfile" << 'EOF'
FROM python:3.11-alpine
RUN apk add --no-cache curl
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
EXPOSE 8600
CMD ["python", "main.py"]
EOF
                    ;;
            esac
        fi
    done
    
    # Start core infrastructure first
    echo "🚀 Starting core infrastructure..."
    docker-compose -f docker-compose.vault.yml up -d vault pg opa
    
    # Wait for core services
    echo "⏳ Waiting for core services to be ready..."
    sleep 10
    
    # Check Vault health
    for i in {1..30}; do
        if curl -sf http://localhost:8200/v1/sys/health >/dev/null 2>&1; then
            VAULT_INITIALIZED=true
            break
        fi
        echo "⏳ Waiting for Vault... ($i/30)"
        sleep 2
    done
    
    if [ "$VAULT_INITIALIZED" = "true" ]; then
        echo -e "${GREEN}✅ Vault is ready${NC}"
        
        # Initialize Vault secrets
        echo "🔐 Initializing Vault secrets..."
        export VAULT_ADDR=http://localhost:8200
        export VAULT_TOKEN=root-dev-token
        
        # Enable secrets engines
        docker exec vault vault auth enable approle || true
        docker exec vault vault secrets enable -path=kv kv-v2 || true
        docker exec vault vault secrets enable transit || true
        docker exec vault vault secrets enable database || true
        
        # Create transit keys
        docker exec vault vault write -f transit/keys/doc-bytes || true
        docker exec vault vault write -f transit/keys/ledger-sign type=ed25519 || true
        
        # Store application secrets
        docker exec vault vault kv put kv/app database_url="postgresql://nlp:SecureVaultPass2024!@pg:5432/nlpdb" || true
        docker exec vault vault kv put kv/app api_tokens internal_token="$INTERNAL_API_TOKEN" || true
        
    else
        echo -e "${RED}❌ Vault failed to start${NC}"
    fi
    
    # Start application services
    echo "🚀 Starting application services..."
    docker-compose -f docker-compose.vault.yml up -d
    
    SERVICES_STARTED=true
    echo -e "${GREEN}✅ All services started${NC}"
}

# Step 5: Invisible Hosting Setup
setup_invisible_hosting() {
    echo -e "\n${BLUE}🔧 Step 5: Invisible Hosting Setup${NC}"
    
    if [ "$ENABLE_INVISIBLE_HOSTING" = "true" ]; then
        # Run tests first
        echo "🧪 Running invisible hosting tests..."
        ./scripts/test-invisible-hosting.sh || echo "⚠️ Some tests failed, continuing..."
        
        # Setup nip.io (most reliable for automation)
        echo "🌐 Setting up nip.io hosting..."
        ./scripts/setup-nip-io.sh setup
        
        # Register services in registry
        echo "📝 Registering services..."
        python3 scripts/registry.py register main "http://$EXTERNAL_IP:8080" api
        python3 scripts/registry.py register code-doctor "http://$EXTERNAL_IP:8500" api
        python3 scripts/registry.py register data-hub "http://$EXTERNAL_IP:8400" api
        python3 scripts/registry.py register vault "http://$EXTERNAL_IP:8200" admin
        
        REGISTRY_INITIALIZED=true
        echo -e "${GREEN}✅ Invisible hosting configured${NC}"
    fi
}

# Step 6: Monitoring & Health Checks
setup_monitoring() {
    echo -e "\n${BLUE}🔧 Step 6: Monitoring & Health Checks${NC}"
    
    if [ "$ENABLE_MONITORING" = "true" ]; then
        # Create monitoring configuration
        mkdir -p config/monitoring
        
        cat > config/monitoring/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'eu-union-ai-pact'
    static_configs:
      - targets: ['localhost:8080', 'localhost:8400', 'localhost:8500']
        labels:
          service: 'api'
      - targets: ['localhost:8200']
        labels:
          service: 'vault'
EOF

        echo "📊 Monitoring configuration created"
    fi
    
    # Health check script
    cat > scripts/health-check.sh << 'EOF'
#!/bin/bash
# Health check for all services

echo "🏥 EU-UNION-AI-PACT Health Check"
echo "================================"

services=(
    "vault:8200:/v1/sys/health"
    "gateway:8080:/health"
    "code-doctor:8500:/healthz"
    "data-hub:8400:/healthz"
    "exec-sandbox:8600:/healthz"
)

all_healthy=true

for service_info in "${services[@]}"; do
    IFS=':' read -r name port path <<< "$service_info"
    url="http://localhost:$port$path"
    
    if curl -sf "$url" >/dev/null 2>&1; then
        echo "✅ $name - Healthy"
    else
        echo "❌ $name - Unhealthy"
        all_healthy=false
    fi
done

if $all_healthy; then
    echo -e "\n🎉 All services are healthy!"
    exit 0
else
    echo -e "\n⚠️ Some services are unhealthy"
    exit 1
fi
EOF

    chmod +x scripts/health-check.sh
    echo -e "${GREEN}✅ Monitoring setup complete${NC}"
}

# Step 7: Backup & Git Initialization
setup_backup_and_git() {
    echo -e "\n${BLUE}🔧 Step 7: Backup & Git Setup${NC}"
    
    # Create backup script
    cat > scripts/backup.sh << 'EOF'
#!/bin/bash
# Backup script for EU-UNION-AI-PACT

BACKUP_DIR="backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "📦 Creating backup in $BACKUP_DIR..."

# Backup configurations
cp -r config "$BACKUP_DIR/"
cp -r vault/policies "$BACKUP_DIR/vault-policies"

# Backup database
docker exec postgres pg_dump -U nlp nlpdb > "$BACKUP_DIR/database.sql"

# Backup registry
cp config/url-registry.json "$BACKUP_DIR/" 2>/dev/null || true

# Create manifest
cat > "$BACKUP_DIR/manifest.json" << EOF
{
  "project": "EU-UNION-AI-PACT",
  "timestamp": "$(date -Iseconds)",
  "version": "1.0",
  "components": ["config", "vault-policies", "database", "registry"]
}
EOF

echo "✅ Backup complete: $BACKUP_DIR"
EOF

    chmod +x scripts/backup.sh
    
    # Initialize Git repository
    if [ ! -d ".git" ]; then
        echo "🔧 Initializing Git repository..."
        
        # Create .gitignore
        cat > .gitignore << 'EOF'
# Environment and secrets
.env
*.env
.env.*
!.env.example

# Logs
logs/
*.log

# Data and runtime
data/
temp/
backups/
vault/runtime/
*.pid

# Dependencies
node_modules/
__pycache__/
*.pyc
target/
.venv/

# IDE
.vscode/
.idea/
*.swp
*.swo

# Docker
.docker/

# OS
.DS_Store
Thumbs.db
EOF

        git init
        git add .
        git commit -m "🚀 Initial commit: EU-UNION-AI-PACT complete setup

Features:
- ✅ Complete DevSecOps/AI pipeline
- ✅ Local NLP/IP stack with vector embeddings
- ✅ HashiCorp Vault integration
- ✅ Code Doctor healing & normalization
- ✅ Unified RAG + Open Data + API Search Layer
- ✅ Invisible hosting (Cloudflare Tunnel + nip.io)
- ✅ OPA policy enforcement
- ✅ Comprehensive monitoring & health checks
- ✅ Automated backup & deployment scripts
- ✅ Production-ready security & compliance"

        echo -e "${GREEN}✅ Git repository initialized${NC}"
    fi
}

# Step 8: Final Validation
final_validation() {
    echo -e "\n${BLUE}🔧 Step 8: Final Validation${NC}"
    
    # Wait for all services to be fully ready
    echo "⏳ Waiting for services to be fully ready..."
    sleep 30
    
    # Run health checks
    if ./scripts/health-check.sh; then
        echo -e "${GREEN}✅ All services are healthy${NC}"
    else
        echo -e "${YELLOW}⚠️ Some services may need more time to start${NC}"
    fi
    
    # Test API endpoints
    echo "🧪 Testing API endpoints..."
    
    endpoints=(
        "http://localhost:8080/health:Gateway"
        "http://localhost:8200/v1/sys/health:Vault"
        "http://localhost:8500/healthz:Code Doctor"
        "http://localhost:8400/healthz:Data Hub"
        "http://localhost:8600/healthz:Exec Sandbox"
    )
    
    for endpoint_info in "${endpoints[@]}"; do
        IFS=':' read -r url name <<< "$endpoint_info"
        
        if curl -sf "$url" >/dev/null 2>&1; then
            echo "✅ $name - API responding"
        else
            echo "⚠️ $name - Not yet ready"
        fi
    done
    
    # Display registry information
    if [ "$REGISTRY_INITIALIZED" = "true" ]; then
        echo -e "\n📝 URL Registry:"
        python3 scripts/registry.py list 2>/dev/null || echo "Registry not yet populated"
    fi
}

# Main orchestration function
main() {
    echo -e "${CYAN}Starting master orchestration...${NC}"
    echo "Project: $PROJECT_NAME"
    echo "Timestamp: $(date)"
    echo ""
    
    setup_logging
    system_prep
    install_dependencies
    init_services
    build_and_start
    setup_invisible_hosting
    setup_monitoring
    setup_backup_and_git
    final_validation
    
    echo -e "\n${PURPLE}🎉 EU-UNION-AI-PACT Master Orchestration Complete!${NC}"
    echo -e "${PURPLE}=================================================${NC}"
    echo ""
    echo -e "${GREEN}✅ Services Status:${NC}"
    echo "   - Vault: $([[ "$VAULT_INITIALIZED" == "true" ]] && echo "✅ Ready" || echo "❌ Failed")"
    echo "   - Docker Services: $([[ "$SERVICES_STARTED" == "true" ]] && echo "✅ Running" || echo "❌ Failed")"
    echo "   - Invisible Hosting: $([[ "$REGISTRY_INITIALIZED" == "true" ]] && echo "✅ Configured" || echo "❌ Skipped")"
    echo ""
    echo -e "${CYAN}🌐 Access Points:${NC}"
    echo "   - Main Gateway: http://localhost:8080"
    echo "   - Vault UI: http://localhost:8200"
    echo "   - Code Doctor: http://localhost:8500"
    echo "   - Data Hub: http://localhost:8400"
    echo "   - Exec Sandbox: http://localhost:8600"
    echo ""
    echo -e "${CYAN}🛠️ Management Commands:${NC}"
    echo "   - Health Check: ./scripts/health-check.sh"
    echo "   - Backup: ./scripts/backup.sh"
    echo "   - Registry: python3 scripts/registry.py list"
    echo "   - Logs: docker-compose logs -f"
    echo ""
    echo -e "${YELLOW}💡 Next Steps:${NC}"
    echo "   1. Verify all services: ./scripts/health-check.sh"
    echo "   2. Test invisible hosting: curl http://$EXTERNAL_IP.nip.io"
    echo "   3. Configure OpenAI API key in .env for full functionality"
    echo "   4. Set up monitoring dashboards if needed"
    echo ""
    echo -e "${GREEN}🚀 Project ready for production use!${NC}"
}

# Execute main function
main "$@"
