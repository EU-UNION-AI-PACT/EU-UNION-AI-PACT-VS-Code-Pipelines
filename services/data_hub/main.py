#!/usr/bin/env python3
from fastapi import FastAPI
from fastapi.responses import HTMLResponse
import uvicorn

app = FastAPI(title="Data Hub - Free")

@app.get("/", response_class=HTMLResponse)
async def root():
    return """
    <html>
    <head><title>Data Hub</title></head>
    <body style="font-family: Arial; margin: 40px;">
        <h1>🗃️ Data Hub</h1>
        <h2>Kostenlose Datenverarbeitung</h2>
        <ul>
            <li><a href="/search?q=test">Daten suchen</a></li>
            <li><a href="/healthz">Health Check</a></li>
        </ul>
    </body>
    </html>
    """

@app.get("/healthz")
async def health():
    return {"status": "healthy", "service": "data-hub", "cost": "free"}

@app.get("/search")
async def search_data(q: str = ""):
    return {
        "query": q,
        "results": [
            {"title": "Beispiel Datensatz", "source": "local", "content": "Kostenlose Testdaten"},
            {"title": "EU Open Data", "source": "europa.eu", "content": "Öffentliche Daten"}
        ],
        "cost": "free"
    }

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8400)
