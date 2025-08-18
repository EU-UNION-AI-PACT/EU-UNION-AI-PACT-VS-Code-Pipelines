#!/bin/bash
# Cloudflare Tunnel Setup - Invisible IP hosting

set -e

echo "🌐 Setting up Cloudflare Tunnel for invisible hosting..."

# Install cloudflared
install_cloudflared() {
    echo "📥 Installing cloudflared..."
    
    if command -v cloudflared &> /dev/null; then
        echo "✅ cloudflared already installed"
        return
    fi
    
    # Download for Linux
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
    chmod +x cloudflared-linux-amd64
    sudo mv cloudflared-linux-amd64 /usr/local/bin/cloudflared
    
    echo "✅ cloudflared installed"
}

# Quick tunnel (temporary)
start_quick_tunnel() {
    echo "🚀 Starting quick tunnel (temporary URL)..."
    echo "Your Flask/Rust app should be running on localhost:8000"
    echo "Starting tunnel..."
    
    cloudflared tunnel --url http://localhost:8000
}

# Persistent tunnel (with custom subdomain)
setup_persistent_tunnel() {
    echo "🔧 Setting up persistent tunnel..."
    
    # Login to Cloudflare
    echo "Please login to Cloudflare (browser will open):"
    cloudflared tunnel login
    
    # Create tunnel
    TUNNEL_NAME="eu-ai-pact-$(date +%s)"
    cloudflared tunnel create $TUNNEL_NAME
    
    # Get tunnel ID
    TUNNEL_ID=$(cloudflared tunnel list | grep $TUNNEL_NAME | awk '{print $1}')
    
    # Create config
    cat > ~/.cloudflared/config.yml << EOF
tunnel: $TUNNEL_ID
credentials-file: ~/.cloudflared/$TUNNEL_ID.json

ingress:
  - hostname: $TUNNEL_NAME.trycloudflare.com
    service: http://localhost:8000
  - hostname: api-$TUNNEL_NAME.trycloudflare.com  
    service: http://localhost:8100
  - service: http_status:404
EOF

    echo "✅ Tunnel configured"
    echo "🌍 Your URLs:"
    echo "   Main: https://$TUNNEL_NAME.trycloudflare.com"
    echo "   API:  https://api-$TUNNEL_NAME.trycloudflare.com"
    
    # Create systemd service
    sudo tee /etc/systemd/system/cloudflared.service > /dev/null <<EOF
[Unit]
Description=Cloudflare Tunnel
After=network.target

[Service]
Type=simple
User=$USER
ExecStart=/usr/local/bin/cloudflared tunnel run $TUNNEL_NAME
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl enable cloudflared
    sudo systemctl start cloudflared
    
    echo "✅ Tunnel service started and enabled"
}

# Dynamic URL registry
create_url_registry() {
    echo "📝 Creating dynamic URL registry..."
    
    cat > url-registry.py << 'EOF'
#!/usr/bin/env python3
import subprocess
import re
import json
import time
from pathlib import Path

def get_tunnel_url():
    """Extract tunnel URL from cloudflared logs"""
    try:
        # Get tunnel URL from status
        result = subprocess.run(['cloudflared', 'tunnel', 'info'], 
                              capture_output=True, text=True)
        
        # Parse URL from output
        url_match = re.search(r'https://([a-z0-9\-]+\.trycloudflare\.com)', result.stdout)
        if url_match:
            return f"https://{url_match.group(1)}"
    except:
        pass
    
    return None

def update_registry(url):
    """Update the URL registry file"""
    registry = {
        "active_base_url": url,
        "updated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "type": "cloudflare_tunnel",
        "invisible_ip": True
    }
    
    with open("config/url-registry.json", "w") as f:
        json.dump(registry, f, indent=2)
    
    print(f"✅ Registry updated: {url}")

if __name__ == "__main__":
    Path("config").mkdir(exist_ok=True)
    
    url = get_tunnel_url()
    if url:
        update_registry(url)
        print(f"🌐 Active URL: {url}")
    else:
        print("❌ No tunnel URL found")
EOF

    chmod +x url-registry.py
    echo "✅ URL registry script created"
}

# Main menu
main() {
    case "${1:-quick}" in
        "install")
            install_cloudflared
            ;;
        "quick")
            install_cloudflared
            start_quick_tunnel
            ;;
        "persistent")
            install_cloudflared
            setup_persistent_tunnel
            create_url_registry
            ;;
        "registry")
            create_url_registry
            ;;
        *)
            echo "Usage: $0 [install|quick|persistent|registry]"
            echo ""
            echo "Commands:"
            echo "  install    - Install cloudflared only"
            echo "  quick      - Start quick tunnel (temporary)"
            echo "  persistent - Setup persistent tunnel with custom domain"
            echo "  registry   - Create URL registry system"
            ;;
    esac
}

main "$@"
