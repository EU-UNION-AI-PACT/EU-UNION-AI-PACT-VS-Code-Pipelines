/**
 * EU AI Pact MCP Client
 * 
 * Node.js client for interacting with the EU AI Pact MCP server
 * Provides AI compliance validation and risk assessment tools
 */
import fetch from "node-fetch";

const BASE = process.env.MCP_BASE_URL || "http://localhost/mcp";
const WASM_BASE = process.env.WASM_BASE_URL || "http://localhost/validate";

class EUAIPactClient {
  constructor(baseUrl = BASE, wasmUrl = WASM_BASE) {
    this.mcpBase = baseUrl;
    this.wasmBase = wasmUrl;
  }

  async listTools() {
    const response = await fetch(`${this.mcpBase}/tools`);
    if (!response.ok) throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    return response.json();
  }

  async invoke(tool, args = {}) {
    const response = await fetch(`${this.mcpBase}/invoke`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ tool, args })
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    return response.json();
  }

  async validateAICompliance(aiSystem) {
    return this.invoke("validate-ai-compliance", { system: aiSystem });
  }

  async performRiskAssessment(category = "general-purpose") {
    return this.invoke("risk-assessment", { category });
  }

  async wasmValidate(payload, validator = "ai-validator") {
    const response = await fetch(`${this.wasmBase}/validate`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ validator, payload })
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    return response.json();
  }

  async getContext() {
    const response = await fetch(`${this.mcpBase}/context`);
    if (!response.ok) throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    return response.json();
  }
}

// Example usage
async function main() {
  const client = new EUAIPactClient();

  try {
    console.log("🔧 Available Tools:");
    const tools = await client.listTools();
    console.log(JSON.stringify(tools, null, 2));

    console.log("\n🔍 AI Compliance Validation:");
    const compliance = await client.validateAICompliance("VS Code AI Assistant");
    console.log(JSON.stringify(compliance, null, 2));

    console.log("\n📊 Risk Assessment:");
    const risk = await client.performRiskAssessment("software-development");
    console.log(JSON.stringify(risk, null, 2));

    console.log("\n⚡ WASM Validation:");
    const wasmResult = await client.wasmValidate({
      aiSystem: {
        name: "Code Analysis Tool",
        type: "development-assistant",
        riskLevel: "limited",
        documentation: "comprehensive"
      }
    });
    console.log(JSON.stringify(wasmResult, null, 2));

  } catch (error) {
    console.error("❌ Error:", error.message);
  }
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main();
}

export { EUAIPactClient };
