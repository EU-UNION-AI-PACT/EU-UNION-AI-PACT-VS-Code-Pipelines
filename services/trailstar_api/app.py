#!/usr/bin/env python3
"""
Flask API mit unsichtbarer IP und dynamischer URL-Erkennung
TrailStar-Prinzip: API erkennt automatisch aktuelle URL
"""

from flask import Flask, request, jsonify
import json
import os
from datetime import datetime

app = Flask(__name__)

# Global registry für aktuelle URL
current_base_url = None

def load_url_registry():
    """Load current URL from registry"""
    global current_base_url
    try:
        with open("config/url-registry.json", "r") as f:
            registry = json.load(f)
            current_base_url = registry.get("active_base_url")
            return registry
    except:
        return None

def get_current_host():
    """Get current host from request"""
    return request.headers.get('Host', 'unknown')

def get_full_url():
    """Get full current URL"""
    host = get_current_host()
    scheme = 'https' if request.is_secure or 'cloudflare' in host else 'http'
    return f"{scheme}://{host}"

@app.route("/")
def index():
    """Main endpoint - shows current URL status"""
    registry = load_url_registry()
    
    return jsonify({
        "message": "EU-UNION-AI-PACT API Active",
        "current_host": get_current_host(),
        "full_url": get_full_url(),
        "registry_url": current_base_url,
        "invisible_hosting": True,
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "registry_info": registry
    })

@app.route("/health")
def health():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "host": get_current_host(),
        "url": get_full_url()
    })

@app.route("/api/connect", methods=['POST'])
def api_connect():
    """TrailStar connection endpoint - 'einpflegen' einer URL"""
    data = request.get_json()
    
    if not data or 'target_url' not in data:
        return jsonify({"error": "target_url required"}), 400
    
    # Simuliere "Einpflegen" der URL
    connection_info = {
        "status": "connected",
        "target_url": data['target_url'],
        "current_host": get_current_host(),
        "current_url": get_full_url(),
        "connection_type": "trailstar",
        "invisible": True,
        "timestamp": datetime.utcnow().isoformat() + "Z"
    }
    
    # Optional: Save connection to registry
    if 'save_to_registry' in data and data['save_to_registry']:
        try:
            os.makedirs("config", exist_ok=True)
            with open("config/connections.json", "w") as f:
                json.dump(connection_info, f, indent=2)
        except Exception as e:
            connection_info['save_error'] = str(e)
    
    return jsonify(connection_info)

@app.route("/api/chat", methods=['POST'])
def chat_endpoint():
    """Chat endpoint mit dynamischer URL"""
    data = request.get_json()
    message = data.get('message', '') if data else ''
    
    # Integration mit bestehender Chat-API
    response = {
        "response": f"Received: {message}",
        "host": get_current_host(),
        "base_url": get_full_url(),
        "invisible_hosting": True,
        "tools_available": ["open_data_search", "code_healing", "sandbox_execute"]
    }
    
    return jsonify(response)

@app.route("/api/deploy", methods=['POST'])
def deploy_endpoint():
    """Deployment endpoint - verbindet App mit aktueller URL"""
    data = request.get_json()
    
    deployment = {
        "status": "deployed",
        "deployment_url": get_full_url(),
        "invisible_ip": True,
        "deployment_type": data.get('type', 'automatic') if data else 'automatic',
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "endpoints": {
            "main": get_full_url(),
            "api": get_full_url() + "/api",
            "health": get_full_url() + "/health",
            "connect": get_full_url() + "/api/connect"
        }
    }
    
    return jsonify(deployment)

@app.route("/registry")
def show_registry():
    """Show current URL registry"""
    registry = load_url_registry()
    
    return jsonify({
        "registry": registry,
        "current_request": {
            "host": get_current_host(),
            "url": get_full_url(),
            "headers": dict(request.headers)
        }
    })

if __name__ == "__main__":
    # Load registry on startup
    load_url_registry()
    
    print("🚀 Starting EU-UNION-AI-PACT Flask API")
    print(f"📍 Current base URL: {current_base_url}")
    print("🔗 TrailStar connection ready")
    
    # Run on all interfaces to accept any host
    app.run(host="0.0.0.0", port=8000, debug=True)
