"""
EU AI Pact Python Client

Python client for interacting with the EU AI Pact MCP server
Provides AI compliance validation and risk assessment tools
"""

import os
import requests
import json
from typing import Dict, Any, Optional


class EUAIPactClient:
    """Client for EU AI Pact MCP services"""
    
    def __init__(self, mcp_base_url: Optional[str] = None, wasm_base_url: Optional[str] = None):
        self.mcp_base = mcp_base_url or os.environ.get("MCP_BASE_URL", "http://localhost/mcp")
        self.wasm_base = wasm_base_url or os.environ.get("WASM_BASE_URL", "http://localhost/validate")
    
    def list_tools(self) -> Dict[str, Any]:
        """Get list of available MCP tools"""
        response = requests.get(f"{self.mcp_base}/tools")
        response.raise_for_status()
        return response.json()
    
    def invoke(self, tool: str, args: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Invoke an MCP tool"""
        payload = {"tool": tool, "args": args or {}}
        response = requests.post(
            f"{self.mcp_base}/invoke",
            json=payload,
            headers={"Content-Type": "application/json"}
        )
        response.raise_for_status()
        return response.json()
    
    def validate_ai_compliance(self, ai_system: str) -> Dict[str, Any]:
        """Validate AI system compliance with EU AI Act"""
        return self.invoke("validate-ai-compliance", {"system": ai_system})
    
    def perform_risk_assessment(self, category: str = "general-purpose") -> Dict[str, Any]:
        """Perform AI risk assessment"""
        return self.invoke("risk-assessment", {"category": category})
    
    def wasm_validate(self, payload: Dict[str, Any], validator: str = "ai-validator") -> Dict[str, Any]:
        """Run WASM-based validation"""
        data = {"validator": validator, "payload": payload}
        response = requests.post(
            f"{self.wasm_base}/validate",
            json=data,
            headers={"Content-Type": "application/json"}
        )
        response.raise_for_status()
        return response.json()
    
    def get_context(self) -> Dict[str, Any]:
        """Get project context and compliance framework info"""
        response = requests.get(f"{self.mcp_base}/context")
        response.raise_for_status()
        return response.json()


def main():
    """Example usage of the EU AI Pact client"""
    client = EUAIPactClient()
    
    try:
        print("🔧 Available Tools:")
        tools = client.list_tools()
        print(json.dumps(tools, indent=2))
        
        print("\n🔍 AI Compliance Validation:")
        compliance = client.validate_ai_compliance("Python AI Assistant")
        print(json.dumps(compliance, indent=2))
        
        print("\n📊 Risk Assessment:")
        risk = client.perform_risk_assessment("software-development")
        print(json.dumps(risk, indent=2))
        
        print("\n⚡ WASM Validation:")
        wasm_result = client.wasm_validate({
            "aiSystem": {
                "name": "Python Code Analyzer",
                "type": "development-tool",
                "riskLevel": "limited",
                "documentation": "comprehensive",
                "hasHumanOversight": True
            }
        })
        print(json.dumps(wasm_result, indent=2))
        
        print("\n📋 Project Context:")
        context = client.get_context()
        print(json.dumps(context, indent=2))
        
    except requests.exceptions.RequestException as e:
        print(f"❌ Error: {e}")
    except Exception as e:
        print(f"❌ Unexpected error: {e}")


if __name__ == "__main__":
    main()
