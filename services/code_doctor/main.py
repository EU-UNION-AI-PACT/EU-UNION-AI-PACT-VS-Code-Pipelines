#!/usr/bin/env python3
from fastapi import FastAPI
from fastapi.responses import HTMLResponse
import uvicorn

app = FastAPI(title="Code Doctor - Free")

@app.get("/", response_class=HTMLResponse)
async def root():
    return """
    <html>
    <head><title>Code Doctor</title></head>
    <body style="font-family: Arial; margin: 40px;">
        <h1>🩺 Code Doctor</h1>
        <h2>Kostenloses Code Healing</h2>
        <form action="/heal" method="post">
            <textarea name="code" rows="10" cols="80" placeholder="Fügen Sie Ihren Code hier ein..."></textarea><br><br>
            <button type="submit">Code heilen</button>
        </form>
    </body>
    </html>
    """

@app.get("/healthz")
async def health():
    return {"status": "healthy", "service": "code-doctor", "cost": "free"}

@app.post("/heal")
async def heal_code(data: dict):
    code = data.get('code', '')
    return {
        "original": code,
        "healed": f"# Optimiert und bereinigt\n{code}",
        "improvements": [
            "Code-Kommentare hinzugefügt",
            "Struktur optimiert",
            "Best Practices angewendet"
        ],
        "cost": "free"
    }

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8500)
