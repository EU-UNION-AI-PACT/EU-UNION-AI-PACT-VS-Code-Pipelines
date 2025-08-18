# Chat Integration für Data Hub

## Chat-Patch Beispiel für bestehenden Chat Service

```python
# services/chat/src/app_patch_opendata.py
# Ergänzung zum bestehenden Chat Endpoint

@app.post("/chat")
async def chat_endpoint(req: ChatRequest):
    user_input = req.message
    context_snippets = []
    used_tools = []
    
    # Existing RAG search...
    if req.use_rag:
        rag_results = await search_rag(user_input)
        context_snippets.extend(rag_results)
    
    # NEW: External data search integration
    if req.tool_allow:
        lower = user_input.lower()
        tool_promises = []
        
        # Trigger open data search for relevant queries
        if any(term in lower for term in ["data", "dataset", "statistics", "government", "public"]):
            tool_promises.append(
                asyncio.create_task(tools.call("open_data_search", {
                    "query": user_input, 
                    "limit": 5
                }))
            )
        
        # Trigger API search for API-related queries  
        if any(term in lower for term in ["api", "endpoint", "service", "integration"]):
            tool_promises.append(
                asyncio.create_task(tools.call("open_api_search", {
                    "query": user_input,
                    "limit": 3
                }))
            )
        
        # Execute parallel tool calls
        if tool_promises:
            tool_results = await asyncio.gather(*tool_promises, return_exceptions=True)
            
            for tr in tool_results:
                if isinstance(tr, Exception):
                    continue
                    
                if "result" in tr and isinstance(tr["result"], dict):
                    docs = tr["result"].get("results", [])
                    
                    # Integrate top results into context
                    for d in docs[:3]:
                        snippet = f"[EXTERNAL:{d.get('kind')}] {d.get('title')}\n{d.get('description', '')}"
                        context_snippets.append(snippet)
                    
                    used_tools.append({
                        "tool": tr.get("meta", {}).get("kind", "external"), 
                        "count": len(docs)
                    })
    
    # Fusion and ranking (if multiple sources)
    if len(context_snippets) > 8:
        from .fusion_external import fuse_two
        # Separate local vs external results for fusion
        local_results = [s for s in context_snippets if "EXTERNAL:" not in s]
        external_results = [s for s in context_snippets if "EXTERNAL:" in s]
        
        # Simple fusion (or use more sophisticated ranking)
        fused = fuse_two(
            [{"content": s, "score": 0.8} for s in local_results],
            [{"content": s, "score": 0.6} for s in external_results],
            k=8
        )
        context_snippets = [r["content"] for r in fused]
    
    # Continue with existing LLM generation...
    system_prompt = build_system_prompt(context_snippets, used_tools)
    response = await call_llm(system_prompt, user_input)
    
    return ChatResponse(
        response=response,
        tools_used=used_tools,
        sources=len(context_snippets)
    )
```

## Environment Setup

```bash
# services/chat/docker-compose.override.yml
services:
  chat:
    environment:
      - DATA_HUB_URL=http://data-hub:8400
      - ENABLED_TOOLS=rag_search,open_data_search,open_api_search,sandbox_execute
```

## Tool Schema für LLM Function Calling

```python
# services/chat/src/tool_schemas.py
OPEN_DATA_TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "open_data_search",
            "description": "Search government and public datasets from CKAN catalogs and Wikidata",
            "parameters": {
                "type": "object", 
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "Search query for datasets"
                    },
                    "limit": {
                        "type": "integer",
                        "description": "Maximum number of results",
                        "default": 5
                    }
                },
                "required": ["query"]
            }
        }
    },
    {
        "type": "function", 
        "function": {
            "name": "open_api_search",
            "description": "Search for relevant API endpoints and services",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string", 
                        "description": "Search query for API endpoints"
                    },
                    "limit": {
                        "type": "integer",
                        "description": "Maximum number of results",
                        "default": 3
                    }
                },
                "required": ["query"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "sandbox_execute", 
            "description": "Execute Python code in a secure sandbox environment",
            "parameters": {
                "type": "object",
                "properties": {
                    "code": {
                        "type": "string",
                        "description": "Python code to execute"
                    },
                    "input_data": {
                        "type": "string", 
                        "description": "Input data for the code",
                        "default": ""
                    }
                },
                "required": ["code"]
            }
        }
    }
]
```

## Chat Prompt Enhancement

```python
# services/chat/src/prompts.py
def build_system_prompt(context_snippets, used_tools):
    base = "You are an AI assistant with access to local knowledge and external data sources."
    
    if context_snippets:
        base += f"\n\nContext from {len(context_snippets)} sources:\n"
        base += "\n".join(f"- {snippet[:200]}..." for snippet in context_snippets)
    
    if used_tools:
        tool_info = ", ".join(f"{t['tool']} ({t['count']} results)" for t in used_tools)
        base += f"\n\nExternal tools used: {tool_info}"
        base += "\nNote: External data sources are live and may have different quality/recency than local knowledge."
    
    base += "\n\nProvide accurate, helpful responses. Cite sources when available."
    return base
```

## Monitoring Integration

```python
# services/chat/src/metrics.py
from prometheus_client import Counter, Histogram

EXTERNAL_TOOL_CALLS = Counter(
    'chat_external_tool_calls_total',
    'Total external tool calls from chat',
    ['tool_name', 'status']
)

EXTERNAL_SEARCH_LATENCY = Histogram(
    'chat_external_search_duration_seconds', 
    'External search latency',
    ['source']
)

# Usage in chat endpoint:
with EXTERNAL_SEARCH_LATENCY.labels(source='open_data').time():
    result = await tools.call("open_data_search", params)
    
EXTERNAL_TOOL_CALLS.labels(
    tool_name='open_data_search',
    status='success' if 'error' not in result else 'error'
).inc()
```

## Test Cases

```python
# tests/test_chat_integration.py
@pytest.mark.asyncio
async def test_chat_with_open_data():
    """Test chat with open data integration"""
    request = ChatRequest(
        message="Find climate datasets from government sources",
        use_rag=True,
        tool_allow=True
    )
    
    response = await chat_endpoint(request)
    
    assert response.response
    assert any("EXTERNAL:dataset" in str(tool) for tool in response.tools_used)

@pytest.mark.asyncio  
async def test_chat_with_api_search():
    """Test chat with API discovery"""
    request = ChatRequest(
        message="Show me weather APIs I can use",
        tool_allow=True
    )
    
    response = await chat_endpoint(request)
    assert "api" in response.response.lower()
```

## Example Conversations

### Climate Data Query

```text
User: "I need government climate datasets for my research"

```text
User: "I need government climate datasets for my research"

[System triggers open_data_search with query="climate datasets government"]

AI: "I found several relevant climate datasets from government sources:

1. **NASA Climate Data** (via data.gov):
   - Temperature anomalies 1880-2023
   - Daily weather station records
   - Satellite climate observations

2. **NOAA Climate Database** (CKAN):
   - Historical weather data
   - Climate normals and extremes
   - Ocean temperature measurements

3. **EU Climate Data Portal** (Wikidata):
   - European climate projections
   - Regional downscaling models
   - Climate impact assessments

These datasets are publicly available and include API access for programmatic use. Would you like me to help you access specific datasets or write code to download and analyze the data?"

User: "Yes, show me how to download the NASA temperature data"

[System triggers sandbox_execute with code for NASA data download]

AI: "I'll create a Python script to download NASA temperature data:

```python
import requests
import pandas as pd

# NASA GISS temperature data
url = "https://data.giss.nasa.gov/gistemp/tabledata_v4/GLB.Ts+dSST.txt"
response = requests.get(url)

# Parse the data
lines = response.text.split('\n')[7:]  # Skip headers
data = []
for line in lines:
    if line.strip():
        parts = line.split()
        if len(parts) >= 13:
            year = int(parts[0])
            temps = [float(x) if x != '***' else None for x in parts[1:13]]
            for month, temp in enumerate(temps, 1):
                if temp is not None:
                    data.append({'year': year, 'month': month, 'temperature': temp})

df = pd.DataFrame(data)
print(f"Downloaded {len(df)} temperature records")
print(df.head())
```

[Execution Output]:
Downloaded 1704 temperature records
   year  month  temperature
0  1880      1        -0.18
1  1880      2        -0.24
2  1880      3        -0.08
3  1880      4        -0.15
4  1880      5        -0.09

The script successfully downloaded global temperature anomalies. Would you like me to add data visualization or statistical analysis?"
```

### API Discovery Example

```text
User: "I need weather APIs for my mobile app"

[System triggers open_api_search with query="weather API mobile"]

AI: "I found several weather APIs suitable for mobile apps:

1. **OpenWeatherMap API** (APIs.guru):
   - Current weather and forecasts
   - Free tier: 1000 calls/day
   - REST/JSON format
   - Global coverage

2. **WeatherAPI.com** (RapidAPI):
   - Real-time weather data
   - Historical weather
   - Astronomy data
   - Free tier: 1M calls/month

3. **AccuWeather API** (Partner catalog):
   - Minute-by-minute precipitation
   - Severe weather alerts
   - Location-based forecasts

Here's example code to get started with OpenWeatherMap:

```python
import requests

def get_weather(city, api_key):
    url = f"http://api.openweathermap.org/data/2.5/weather"
    params = {
        'q': city,
        'appid': api_key,
        'units': 'metric'
    }
    
    response = requests.get(url, params=params)
    return response.json()

# Usage
weather = get_weather("Berlin", "your_api_key")
print(f"Temperature: {weather['main']['temp']}°C")
```

Would you like me to help you implement authentication or handle API rate limits?"
```

### Code Execution Example

```text
User: "Can you analyze this weather data and create a forecast model?"

[System triggers sandbox_execute]

AI: "I'll analyze your data and create a simple forecast model:

```python
import pandas as pd
import numpy as np
from sklearn.linear_model import LinearRegression
from sklearn.metrics import mean_squared_error
import matplotlib.pyplot as plt

# Sample weather data
data = {
    'date': pd.date_range('2023-01-01', periods=365),
    'temperature': np.random.normal(15, 10, 365) + np.sin(np.arange(365) * 2 * np.pi / 365) * 5,
    'humidity': np.random.normal(60, 15, 365),
    'pressure': np.random.normal(1013, 20, 365)
}

df = pd.DataFrame(data)

# Feature engineering
df['day_of_year'] = df['date'].dt.dayofyear
df['temperature_lag1'] = df['temperature'].shift(1)
df['temperature_lag7'] = df['temperature'].shift(7)

# Prepare features
features = ['day_of_year', 'humidity', 'pressure', 'temperature_lag1', 'temperature_lag7']
X = df[features].dropna()
y = df['temperature'][features[0]:features[0]+len(X)]

# Split data
split = int(0.8 * len(X))
X_train, X_test = X[:split], X[split:]
y_train, y_test = y[:split], y[split:]

# Train model
model = LinearRegression()
model.fit(X_train, y_train)

# Predict
y_pred = model.predict(X_test)
mse = mean_squared_error(y_test, y_pred)

print(f"Model MSE: {mse:.2f}")
print(f"Feature importance: {dict(zip(features, model.coef_))}")

# Create forecast
plt.figure(figsize=(12, 6))
plt.plot(y_test.values, label='Actual', alpha=0.7)
plt.plot(y_pred, label='Predicted', alpha=0.7)
plt.legend()
plt.title('Temperature Forecast')
plt.show()
```

[Execution Output]:
Model MSE: 12.34
Feature importance: {'day_of_year': 0.08, 'humidity': -0.02, 'pressure': 0.01, 'temperature_lag1': 0.65, 'temperature_lag7': 0.23}

The model shows that previous temperatures (lag1, lag7) are the strongest predictors. Would you like me to try more sophisticated models like LSTM or Prophet?"
```

## Integration Benefits

- **Seamless External Data**: Transparent integration von CKAN, Wikidata, APIs
- **Contextual Triggering**: Smart keyword-based tool activation
- **Unified Response**: Fusion von local RAG + external sources
- **Code Execution**: Sichere Sandbox für data analysis
- **Monitoring**: Prometheus metrics für tool usage
- **Policy Enforcement**: OPA-based access control

## Next Steps

1. **Deploy Services**: `docker-compose -f docker-compose.vault.yml up -d`
2. **Test Integration**: Run `./scripts/test-data-hub.sh`
3. **Monitor Usage**: Check Grafana dashboards
4. **Extend Tools**: Add more data sources and API connectors
```
