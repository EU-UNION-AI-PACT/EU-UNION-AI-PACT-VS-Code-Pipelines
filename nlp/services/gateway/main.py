#!/usr/bin/env python3
from fastapi import FastAPI
from fastapi.responses import HTMLResponse
import uvicorn

app = FastAPI(title="EU-UNION-AI-PACT Gateway")

@app.get("/", response_class=HTMLResponse)
async def root():
    return """
    <!DOCTYPE html>
    <html>
    <head>
        <title>EU-UNION-AI-PACT</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
            .container { background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
            h1 { color: #1f5582; }
            .status { color: #28a745; font-weight: bold; }
            .services { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-top: 20px; }
            .service { background: #e9ecef; padding: 15px; border-radius: 5px; text-decoration: none; color: #333; }
            .service:hover { background: #dee2e6; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🇪🇺 EU-UNION-AI-PACT</h1>
            <p class="status">✅ System läuft - 100% kostenfrei</p>
            
            <h2>🛠️ Services</h2>
            <div class="services">
                <a href="/health" class="service">
                    <h3>🏥 Health Check</h3>
                    <p>System Status</p>
                </a>
                <a href="http://localhost:8200" class="service">
                    <h3>🔐 Vault</h3>
                    <p>Security Management</p>
                </a>
                <a href="http://localhost:8500" class="service">
                    <h3>🩺 Code Doctor</h3>
                    <p>Code Healing</p>
                </a>
                <a href="http://localhost:8400" class="service">
                    <h3>🗃️ Data Hub</h3>
                    <p>Data Processing</p>
                </a>
            </div>
            
            <h2>📊 Status</h2>
            <p>Version: 1.0 | Mode: Development | Cost: Free</p>
        </div>
    </body>
    </html>
    """

@app.get("/health")
async def health():
    return {
        "status": "healthy", 
        "service": "gateway", 
        "version": "1.0",
        "cost": "free",
        "services": {
            "vault": "http://localhost:8200",
            "code-doctor": "http://localhost:8500",
            "data-hub": "http://localhost:8400"
        }
    }

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080)
