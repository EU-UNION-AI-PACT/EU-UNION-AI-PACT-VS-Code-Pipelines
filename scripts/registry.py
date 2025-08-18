#!/usr/bin/env python3
"""
Dynamic URL Registry Service
Similar to TrailStar behavior - dynamic base URL injection
"""

import json
import os
import requests
import time
from pathlib import Path
from typing import Dict, Optional, List
from dataclasses import dataclass, asdict
from datetime import datetime, timezone

@dataclass
class URLEntry:
    """URL registry entry"""
    name: str
    url: str
    type: str  # tunnel, nip, static, api
    status: str  # active, inactive, error
    created_at: str
    last_check: str
    metadata: Dict = None

class URLRegistry:
    """Dynamic URL registry manager"""
    
    def __init__(self, registry_file: str = "config/url-registry.json"):
        self.registry_file = Path(registry_file)
        self.registry_file.parent.mkdir(exist_ok=True)
        self.urls: Dict[str, URLEntry] = {}
        self.load()
    
    def load(self) -> None:
        """Load registry from file"""
        if self.registry_file.exists():
            try:
                with open(self.registry_file, 'r') as f:
                    data = json.load(f)
                    
                for name, entry_data in data.get('urls', {}).items():
                    self.urls[name] = URLEntry(**entry_data)
                    
            except Exception as e:
                print(f"❌ Error loading registry: {e}")
                self.urls = {}
    
    def save(self) -> None:
        """Save registry to file"""
        try:
            registry_data = {
                'version': '1.0',
                'updated_at': datetime.now(timezone.utc).isoformat(),
                'urls': {name: asdict(entry) for name, entry in self.urls.items()}
            }
            
            with open(self.registry_file, 'w') as f:
                json.dump(registry_data, f, indent=2)
                
        except Exception as e:
            print(f"❌ Error saving registry: {e}")
    
    def register(self, name: str, url: str, url_type: str = "static", metadata: Dict = None) -> URLEntry:
        """Register new URL"""
        now = datetime.now(timezone.utc).isoformat()
        
        entry = URLEntry(
            name=name,
            url=url,
            type=url_type,
            status="active",
            created_at=now,
            last_check=now,
            metadata=metadata or {}
        )
        
        self.urls[name] = entry
        self.save()
        
        print(f"✅ Registered: {name} -> {url}")
        return entry
    
    def get(self, name: str) -> Optional[URLEntry]:
        """Get URL entry"""
        return self.urls.get(name)
    
    def get_base_url(self) -> str:
        """Get primary base URL"""
        # Priority: tunnel > nip > static
        priorities = ["tunnel", "nip", "api", "static"]
        
        for url_type in priorities:
            for entry in self.urls.values():
                if entry.type == url_type and entry.status == "active":
                    return entry.url
        
        return "http://localhost:8000"  # fallback
    
    def health_check(self, name: str = None) -> Dict:
        """Check URL health"""
        results = {}
        
        entries_to_check = [self.urls[name]] if name and name in self.urls else self.urls.values()
        
        for entry in entries_to_check:
            try:
                response = requests.get(f"{entry.url}/health", timeout=5)
                
                if response.status_code == 200:
                    entry.status = "active"
                    results[entry.name] = {"status": "active", "response_time": response.elapsed.total_seconds()}
                else:
                    entry.status = "error"
                    results[entry.name] = {"status": "error", "code": response.status_code}
                    
                entry.last_check = datetime.now(timezone.utc).isoformat()
                
            except Exception as e:
                entry.status = "inactive"
                results[entry.name] = {"status": "inactive", "error": str(e)}
                entry.last_check = datetime.now(timezone.utc).isoformat()
        
        self.save()
        return results
    
    def list_urls(self) -> List[Dict]:
        """List all registered URLs"""
        return [asdict(entry) for entry in self.urls.values()]
    
    def remove(self, name: str) -> bool:
        """Remove URL from registry"""
        if name in self.urls:
            del self.urls[name]
            self.save()
            print(f"❌ Removed: {name}")
            return True
        return False

class TrailStarConnector:
    """TrailStar-like connection manager"""
    
    def __init__(self, registry: URLRegistry):
        self.registry = registry
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'EU-UNION-AI-PACT/1.0 TrailStarConnector'
        })
    
    def discover_endpoints(self) -> Dict:
        """Discover available endpoints"""
        base_url = self.registry.get_base_url()
        
        try:
            response = self.session.get(f"{base_url}/.well-known/endpoints")
            
            if response.status_code == 200:
                return response.json()
            else:
                # Fallback discovery
                return self._fallback_discovery(base_url)
                
        except Exception as e:
            print(f"❌ Endpoint discovery failed: {e}")
            return self._fallback_discovery(base_url)
    
    def _fallback_discovery(self, base_url: str) -> Dict:
        """Fallback endpoint discovery"""
        standard_endpoints = [
            "/api/v1/chat",
            "/api/v1/deploy", 
            "/api/v1/status",
            "/health",
            "/metrics"
        ]
        
        discovered = {"base_url": base_url, "endpoints": {}}
        
        for endpoint in standard_endpoints:
            try:
                response = self.session.head(f"{base_url}{endpoint}", timeout=3)
                if response.status_code < 500:
                    discovered["endpoints"][endpoint.split('/')[-1]] = f"{base_url}{endpoint}"
            except:
                pass
        
        return discovered
    
    def connect(self, target: str = None) -> Dict:
        """Connect to target or auto-discover"""
        if target:
            # Direct connection
            try:
                response = self.session.get(f"{target}/health", timeout=5)
                if response.status_code == 200:
                    self.registry.register("direct", target, "static")
                    return {"status": "connected", "target": target}
            except Exception as e:
                return {"status": "failed", "error": str(e)}
        else:
            # Auto-discovery
            base_url = self.registry.get_base_url()
            endpoints = self.discover_endpoints()
            
            return {
                "status": "discovered",
                "base_url": base_url,
                "endpoints": endpoints
            }

def main():
    """CLI interface for registry management"""
    import sys
    
    registry = URLRegistry()
    connector = TrailStarConnector(registry)
    
    if len(sys.argv) < 2:
        print("Usage: python registry.py [command] [args...]")
        print("\nCommands:")
        print("  register <name> <url> [type]  - Register new URL")
        print("  get <name>                    - Get URL entry")
        print("  list                          - List all URLs")
        print("  health [name]                 - Check URL health")
        print("  base                          - Get base URL")
        print("  connect [target]              - Connect/discover")
        print("  remove <name>                 - Remove URL")
        return
    
    command = sys.argv[1]
    
    if command == "register":
        if len(sys.argv) < 4:
            print("Usage: register <name> <url> [type]")
            return
        
        name = sys.argv[2]
        url = sys.argv[3]
        url_type = sys.argv[4] if len(sys.argv) > 4 else "static"
        
        entry = registry.register(name, url, url_type)
        print(json.dumps(asdict(entry), indent=2))
    
    elif command == "get":
        if len(sys.argv) < 3:
            print("Usage: get <name>")
            return
        
        entry = registry.get(sys.argv[2])
        if entry:
            print(json.dumps(asdict(entry), indent=2))
        else:
            print(f"❌ URL '{sys.argv[2]}' not found")
    
    elif command == "list":
        urls = registry.list_urls()
        print(json.dumps(urls, indent=2))
    
    elif command == "health":
        name = sys.argv[2] if len(sys.argv) > 2 else None
        results = registry.health_check(name)
        print(json.dumps(results, indent=2))
    
    elif command == "base":
        base_url = registry.get_base_url()
        print(base_url)
    
    elif command == "connect":
        target = sys.argv[2] if len(sys.argv) > 2 else None
        result = connector.connect(target)
        print(json.dumps(result, indent=2))
    
    elif command == "remove":
        if len(sys.argv) < 3:
            print("Usage: remove <name>")
            return
        
        if registry.remove(sys.argv[2]):
            print("✅ Removed successfully")
        else:
            print("❌ URL not found")
    
    else:
        print(f"❌ Unknown command: {command}")

if __name__ == "__main__":
    main()
