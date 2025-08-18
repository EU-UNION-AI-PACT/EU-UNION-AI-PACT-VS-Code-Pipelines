import express from "express";
import cors from "cors";
import morgan from "morgan";
import { v4 as uuidv4 } from "uuid";

const PORT = process.env.MCP_PORT || 7000;
const BASE = process.env.MCP_BASE_PATH || "/mcp";

// Simulierte Tools & Kontexte für EU AI Pact
const tools = [
  { name: "echo", description: "Echoes a string back." },
  { name: "uuid", description: "Generates a UUID." },
  { name: "validate-ai-compliance", description: "Validates AI system compliance with EU AI Act." },
  { name: "risk-assessment", description: "Performs AI risk assessment according to EU guidelines." }
];

const app = express();
app.use(cors());
app.use(express.json());
app.use(morgan("tiny"));

// Health
app.get(`${BASE}/healthz`, (_req, res) => res.json({ 
  ok: true, 
  service: "eu-ai-pact-mcp", 
  ts: Date.now(),
  version: "0.1.0"
}));

// Liste Tools
app.get(`${BASE}/tools`, (_req, res) => {
  res.json({ tools });
});

// Tool Invocation
app.post(`${BASE}/invoke`, (req, res) => {
  const { tool, args } = req.body || {};
  if (!tool) return res.status(400).json({ error: "tool required" });

  if (tool === "echo") {
    return res.json({ tool, output: args?.text ?? "", status: "ok" });
  }
  if (tool === "uuid") {
    return res.json({ tool, output: uuidv4(), status: "ok" });
  }
  if (tool === "validate-ai-compliance") {
    const aiSystem = args?.system || "unknown";
    const compliance = {
      system: aiSystem,
      riskLevel: "medium",
      compliant: true,
      requirements: ["transparency", "human-oversight", "data-governance"],
      timestamp: new Date().toISOString()
    };
    return res.json({ tool, output: compliance, status: "ok" });
  }
  if (tool === "risk-assessment") {
    const assessment = {
      riskCategory: args?.category || "general-purpose",
      riskLevel: "acceptable",
      mitigationMeasures: ["regular-monitoring", "bias-testing", "documentation"],
      compliance: "eu-ai-act-compliant",
      timestamp: new Date().toISOString()
    };
    return res.json({ tool, output: assessment, status: "ok" });
  }
  return res.status(404).json({ error: "unknown_tool" });
});

// Kontext (EU AI Pact Projektinfos)
app.get(`${BASE}/context`, (_req, res) => {
  res.json({
    project: "eu-union-ai-pact-vs-code-pipelines",
    version: "0.1.0",
    framework: "EU AI Act Compliance",
    endpoints: {
      tools: `${BASE}/tools`,
      invoke: `${BASE}/invoke`,
      context: `${BASE}/context`
    },
    aiActCompliance: {
      version: "2024",
      supportedRiskCategories: ["unacceptable", "high", "limited", "minimal"],
      assessmentTools: ["risk-assessment", "validate-ai-compliance"]
    }
  });
});

app.listen(PORT, () => {
  console.log(`[eu-ai-pact-mcp] Listening on :${PORT}${BASE}`);
});
