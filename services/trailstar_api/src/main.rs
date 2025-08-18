// Rust Axum API - Host-agnostisch und unsichtbare IP
// Cargo.toml dependencies:
// axum = "0.7"
// tokio = { version = "1.0", features = ["full"] }
// serde = { version = "1.0", features = ["derive"] }
// serde_json = "1.0"

use axum::{
    extract::{Host, Json},
    http::{HeaderMap, StatusCode},
    response::Json as ResponseJson,
    routing::{get, post},
    Router,
};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use tokio::fs;

#[derive(Serialize, Deserialize)]
struct UrlRegistry {
    active_base_url: Option<String>,
    updated_at: String,
    #[serde(rename = "type")]
    url_type: String,
    invisible_ip: bool,
}

#[derive(Serialize, Deserialize)]
struct ConnectRequest {
    target_url: String,
    save_to_registry: Option<bool>,
}

#[derive(Serialize)]
struct ApiResponse {
    status: String,
    host: String,
    full_url: String,
    invisible_hosting: bool,
    timestamp: String,
}

#[derive(Serialize)]
struct ConnectionResponse {
    status: String,
    target_url: String,
    current_host: String,
    current_url: String,
    connection_type: String,
    invisible: bool,
    timestamp: String,
}

// Load URL registry
async fn load_url_registry() -> Option<UrlRegistry> {
    if let Ok(content) = fs::read_to_string("config/url-registry.json").await {
        serde_json::from_str(&content).ok()
    } else {
        None
    }
}

// Get current timestamp
fn get_timestamp() -> String {
    chrono::Utc::now().to_rfc3339()
}

// Main index endpoint
async fn index(Host(host): Host, headers: HeaderMap) -> ResponseJson<serde_json::Value> {
    let registry = load_url_registry().await;
    let scheme = if headers.get("x-forwarded-proto").is_some() 
        || host.contains("cloudflare") 
        || host.contains("trycloudflare") {
        "https"
    } else {
        "http"
    };
    let full_url = format!("{}://{}", scheme, host);

    ResponseJson(serde_json::json!({
        "message": "EU-UNION-AI-PACT Rust API Active",
        "current_host": host,
        "full_url": full_url,
        "registry_url": registry.as_ref().and_then(|r| r.active_base_url.clone()),
        "invisible_hosting": true,
        "timestamp": get_timestamp(),
        "registry_info": registry
    }))
}

// Health check
async fn health(Host(host): Host, headers: HeaderMap) -> ResponseJson<ApiResponse> {
    let scheme = if headers.get("x-forwarded-proto").is_some() 
        || host.contains("cloudflare") {
        "https"
    } else {
        "http"
    };
    let full_url = format!("{}://{}", scheme, host);

    ResponseJson(ApiResponse {
        status: "healthy".to_string(),
        host,
        full_url,
        invisible_hosting: true,
        timestamp: get_timestamp(),
    })
}

// TrailStar connection endpoint
async fn api_connect(
    Host(host): Host,
    headers: HeaderMap,
    Json(payload): Json<ConnectRequest>
) -> Result<ResponseJson<ConnectionResponse>, StatusCode> {
    let scheme = if headers.get("x-forwarded-proto").is_some() 
        || host.contains("cloudflare") {
        "https"
    } else {
        "http"
    };
    let current_url = format!("{}://{}", scheme, host);

    let connection = ConnectionResponse {
        status: "connected".to_string(),
        target_url: payload.target_url.clone(),
        current_host: host,
        current_url,
        connection_type: "trailstar".to_string(),
        invisible: true,
        timestamp: get_timestamp(),
    };

    // Save to registry if requested
    if payload.save_to_registry.unwrap_or(false) {
        if let Err(_) = fs::create_dir_all("config").await {
            return Err(StatusCode::INTERNAL_SERVER_ERROR);
        }
        
        let json = serde_json::to_string_pretty(&connection)
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
        
        if let Err(_) = fs::write("config/connections.json", json).await {
            return Err(StatusCode::INTERNAL_SERVER_ERROR);
        }
    }

    Ok(ResponseJson(connection))
}

// Chat endpoint
async fn chat_endpoint(
    Host(host): Host,
    headers: HeaderMap,
    Json(payload): Json<HashMap<String, serde_json::Value>>
) -> ResponseJson<serde_json::Value> {
    let scheme = if headers.get("x-forwarded-proto").is_some() 
        || host.contains("cloudflare") {
        "https"
    } else {
        "http"
    };
    let full_url = format!("{}://{}", scheme, host);
    
    let message = payload.get("message")
        .and_then(|v| v.as_str())
        .unwrap_or("");

    ResponseJson(serde_json::json!({
        "response": format!("Rust API received: {}", message),
        "host": host,
        "base_url": full_url,
        "invisible_hosting": true,
        "tools_available": ["open_data_search", "code_healing", "sandbox_execute"],
        "timestamp": get_timestamp()
    }))
}

// Deploy endpoint
async fn deploy_endpoint(
    Host(host): Host,
    headers: HeaderMap,
    Json(payload): Json<HashMap<String, serde_json::Value>>
) -> ResponseJson<serde_json::Value> {
    let scheme = if headers.get("x-forwarded-proto").is_some() 
        || host.contains("cloudflare") {
        "https"
    } else {
        "http"
    };
    let full_url = format!("{}://{}", scheme, host);
    
    let deployment_type = payload.get("type")
        .and_then(|v| v.as_str())
        .unwrap_or("automatic");

    ResponseJson(serde_json::json!({
        "status": "deployed",
        "deployment_url": full_url,
        "invisible_ip": true,
        "deployment_type": deployment_type,
        "timestamp": get_timestamp(),
        "endpoints": {
            "main": full_url,
            "api": format!("{}/api", full_url),
            "health": format!("{}/health", full_url),
            "connect": format!("{}/api/connect", full_url)
        }
    }))
}

// Show registry
async fn show_registry(Host(host): Host, headers: HeaderMap) -> ResponseJson<serde_json::Value> {
    let registry = load_url_registry().await;
    let scheme = if headers.get("x-forwarded-proto").is_some() 
        || host.contains("cloudflare") {
        "https"
    } else {
        "http"
    };
    let full_url = format!("{}://{}", scheme, host);

    let mut header_map = HashMap::new();
    for (name, value) in headers.iter() {
        if let Ok(value_str) = value.to_str() {
            header_map.insert(name.to_string(), value_str.to_string());
        }
    }

    ResponseJson(serde_json::json!({
        "registry": registry,
        "current_request": {
            "host": host,
            "url": full_url,
            "headers": header_map
        }
    }))
}

#[tokio::main]
async fn main() {
    println!("🚀 Starting EU-UNION-AI-PACT Rust API");
    
    // Load registry on startup
    if let Some(registry) = load_url_registry().await {
        println!("📍 Current base URL: {:?}", registry.active_base_url);
    }
    println!("🔗 TrailStar connection ready");

    let app = Router::new()
        .route("/", get(index))
        .route("/health", get(health))
        .route("/api/connect", post(api_connect))
        .route("/api/chat", post(chat_endpoint))
        .route("/api/deploy", post(deploy_endpoint))
        .route("/registry", get(show_registry));

    let listener = tokio::net::TcpListener::bind("0.0.0.0:8000")
        .await
        .unwrap();

    println!("🌍 Server running on http://0.0.0.0:8000");
    println!("💡 Accepts any host header - ready for invisible hosting");

    axum::serve(listener, app).await.unwrap();
}
