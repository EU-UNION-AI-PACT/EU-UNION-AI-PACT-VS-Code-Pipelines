#!/bin/bash
# nip.io setup - IP basierte Domain ohne Registrierung

set -e

echo "🌐 Setting up nip.io based hosting..."

# Get public IP
get_public_ip() {
    echo "🔍 Detecting public IP..."
    
    IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || curl -s icanhazip.com)
    
    if [ -z "$IP" ]; then
        echo "❌ Could not detect public IP"
        echo "Please provide your public IP manually:"
        read -p "IP: " IP
    fi
    
    echo "📍 Detected IP: $IP"
    echo $IP
}

# Create nip.io domains
create_nip_domains() {
    local ip=$1
    local ip_dashed=$(echo $ip | tr '.' '-')
    
    echo "🏗️ Creating nip.io domains for IP: $ip"
    
    # Create domain list
    cat > config/nip-domains.json << EOF
{
  "ip": "$ip",
  "domains": {
    "main": "$ip_dashed.nip.io",
    "api": "api-$ip_dashed.nip.io", 
    "admin": "admin-$ip_dashed.nip.io",
    "ws": "ws-$ip_dashed.nip.io"
  },
  "urls": {
    "main": "https://$ip_dashed.nip.io",
    "api": "https://api-$ip_dashed.nip.io",
    "admin": "https://admin-$ip_dashed.nip.io",
    "ws": "wss://ws-$ip_dashed.nip.io"
  },
  "created_at": "$(date -Iseconds)"
}
EOF

    echo "✅ nip.io domains created:"
    echo "   Main: $ip_dashed.nip.io"
    echo "   API:  api-$ip_dashed.nip.io"
    echo "   Admin: admin-$ip_dashed.nip.io"
    
    return 0
}

# Create Caddy configuration
create_caddy_config() {
    local ip=$1
    local ip_dashed=$(echo $ip | tr '.' '-')
    
    echo "🔧 Creating Caddy configuration..."
    
    mkdir -p config/caddy
    
    cat > config/caddy/Caddyfile << EOF
# nip.io Caddy configuration
$ip_dashed.nip.io {
    encode gzip
    
    # Main website/app
    reverse_proxy 127.0.0.1:8000
    
    # Headers for security
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        Referrer-Policy "strict-origin-when-cross-origin"
    }
    
    # Logging
    log {
        output file /var/log/caddy/main.log
        format json
    }
}

api-$ip_dashed.nip.io {
    encode gzip
    
    # API endpoints
    reverse_proxy 127.0.0.1:8100
    
    # CORS for API
    header {
        Access-Control-Allow-Origin "*"
        Access-Control-Allow-Methods "GET,POST,PUT,DELETE,OPTIONS"
        Access-Control-Allow-Headers "Content-Type,Authorization"
        Strict-Transport-Security "max-age=31536000"
    }
    
    log {
        output file /var/log/caddy/api.log
        format json
    }
}

admin-$ip_dashed.nip.io {
    encode gzip
    
    # Admin interface
    reverse_proxy 127.0.0.1:8200
    
    # Basic auth (change credentials!)
    basicauth {
        admin \$2a\$14\$hPDxRBK0PqcUzTAP3HCo..Tr3EjP7VYslD9LLcKN7SiZMqGZOK5iq
    }
    
    log {
        output file /var/log/caddy/admin.log
        format json
    }
}
EOF

    echo "✅ Caddy configuration created"
    echo "💡 Default admin credentials: admin/secret (change these!)"
}

# Create docker-compose for nip.io setup
create_docker_compose() {
    local ip=$1
    local ip_dashed=$(echo $ip | tr '.' '-')
    
    echo "🐳 Creating Docker Compose configuration..."
    
    cat > docker-compose.nip.yml << EOF
version: "3.9"

services:
  caddy:
    image: caddy:2
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./config/caddy/Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
      - ./logs:/var/log/caddy
    environment:
      - ACME_AGREE=true
    restart: unless-stopped
    networks: [nip_net]
    
  trailstar-api:
    build: ./services/trailstar_api
    environment:
      - HOST=0.0.0.0
      - PORT=8000
      - BASE_URL=https://$ip_dashed.nip.io
      - API_URL=https://api-$ip_dashed.nip.io
    ports:
      - "8000:8000"
    volumes:
      - ./config:/app/config:ro
    restart: unless-stopped
    networks: [nip_net]
    
  api-service:
    build: ./services/api
    environment:
      - HOST=0.0.0.0
      - PORT=8100
      - BASE_URL=https://api-$ip_dashed.nip.io
    ports:
      - "8100:8100"
    restart: unless-stopped
    networks: [nip_net]
    
  admin-panel:
    image: nginx:alpine
    volumes:
      - ./admin:/usr/share/nginx/html:ro
    ports:
      - "8200:80"
    restart: unless-stopped
    networks: [nip_net]

volumes:
  caddy_data:
  caddy_config:

networks:
  nip_net:
    driver: bridge
EOF

    echo "✅ Docker Compose configuration created"
}

# Test nip.io resolution
test_nip_resolution() {
    local ip=$1
    local ip_dashed=$(echo $ip | tr '.' '-')
    local domain="$ip_dashed.nip.io"
    
    echo "🧪 Testing nip.io DNS resolution..."
    
    resolved_ip=$(dig +short $domain @8.8.8.8)
    
    if [ "$resolved_ip" = "$ip" ]; then
        echo "✅ DNS resolution works: $domain -> $ip"
        return 0
    else
        echo "❌ DNS resolution failed: $domain -> $resolved_ip (expected: $ip)"
        return 1
    fi
}

# Create SSL cert request script
create_ssl_script() {
    local ip=$1
    local ip_dashed=$(echo $ip | tr '.' '-')
    
    echo "🔒 Creating SSL certificate script..."
    
    cat > scripts/setup-ssl.sh << EOF
#!/bin/bash
# SSL setup for nip.io domains

set -e

echo "🔒 Setting up SSL certificates for nip.io domains..."

# Install certbot if not present
if ! command -v certbot &> /dev/null; then
    echo "📦 Installing certbot..."
    sudo apt update
    sudo apt install -y certbot
fi

# Request certificates
echo "📜 Requesting certificates..."

certbot certonly --standalone \
  -d $ip_dashed.nip.io \
  -d api-$ip_dashed.nip.io \
  -d admin-$ip_dashed.nip.io \
  --agree-tos \
  --non-interactive \
  --email admin@$ip_dashed.nip.io

echo "✅ SSL certificates obtained"
echo "💡 Certificates location: /etc/letsencrypt/live/$ip_dashed.nip.io/"
EOF

    chmod +x scripts/setup-ssl.sh
    echo "✅ SSL setup script created"
}

# Main setup function
main() {
    case "${1:-setup}" in
        "setup")
            mkdir -p config scripts logs
            
            IP=$(get_public_ip)
            create_nip_domains "$IP"
            create_caddy_config "$IP"
            create_docker_compose "$IP"
            create_ssl_script "$IP"
            
            if test_nip_resolution "$IP"; then
                echo ""
                echo "🎉 nip.io setup complete!"
                echo ""
                echo "🌐 Your domains:"
                echo "   Main: https://$(echo $IP | tr '.' '-').nip.io"
                echo "   API:  https://api-$(echo $IP | tr '.' '-').nip.io"
                echo "   Admin: https://admin-$(echo $IP | tr '.' '-').nip.io"
                echo ""
                echo "🚀 Next steps:"
                echo "   1. Start services: docker-compose -f docker-compose.nip.yml up -d"
                echo "   2. Setup SSL: ./scripts/setup-ssl.sh"
                echo "   3. Test: curl https://$(echo $IP | tr '.' '-').nip.io"
            else
                echo "❌ Setup completed but DNS test failed"
                echo "💡 You may need to wait a few minutes for DNS propagation"
            fi
            ;;
        "test")
            IP=$(get_public_ip)
            test_nip_resolution "$IP"
            ;;
        "ssl")
            ./scripts/setup-ssl.sh
            ;;
        *)
            echo "Usage: $0 [setup|test|ssl]"
            echo ""
            echo "Commands:"
            echo "  setup - Full nip.io setup"
            echo "  test  - Test DNS resolution"
            echo "  ssl   - Setup SSL certificates"
            ;;
    esac
}

main "$@"
