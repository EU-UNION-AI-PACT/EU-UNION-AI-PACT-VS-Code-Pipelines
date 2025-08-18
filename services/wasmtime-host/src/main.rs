use anyhow::Result;
use axum::{routing::post, Router, Json};
use axum::http::HeaderMap;
use serde::{Deserialize, Serialize};
use std::{collections::HashMap, net::SocketAddr, sync::Arc};
use wasmtime::{Engine, Module, Store, Linker, Config, Val, ValType};
use parking_lot::RwLock;

#[derive(Deserialize)]
struct ValidationReq {
    #[serde(default)]
    validator: String,
    payload: serde_json::Value,
}

#[derive(Serialize)]
struct ValidationResp {
    result: serde_json::Value,
    validator: String,
    fuel_used: u64,
    compliance_score: i32,
}

struct ValidatorModules {
    engine: Engine,
    modules: RwLock<HashMap<String, Arc<Module>>>,
    base_dir: String,
    default_validator: String,
}

impl ValidatorModules {
    fn new(base_dir: String, default_validator: String) -> Result<Self> {
        let mut cfg = Config::new();
        cfg.consume_fuel(true);
        let engine = Engine::new(&cfg)?;
        Ok(Self {
            engine,
            modules: RwLock::new(HashMap::new()),
            base_dir,
            default_validator,
        })
    }

    fn module_for(&self, validator: &str) -> Result<Arc<Module>> {
        {
            if let Some(m) = self.modules.read().get(validator).cloned() {
                return Ok(m);
            }
        }
        let path = format!("{}/{}.wasm", self.base_dir, validator);
        let effective = if std::fs::metadata(&path).is_ok() {
            path
        } else {
            format!("{}/{}.wasm", self.base_dir, self.default_validator)
        };
        let module = Arc::new(Module::from_file(&self.engine, &effective)?);
        self.modules.write().insert(validator.to_string(), module.clone());
        Ok(module)
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    let vm = Arc::new(ValidatorModules::new(
        "/runtime/validators".into(),
        "ai-validator".into(),
    )?);

    let app = Router::new()
        .route("/validate", post(validate))
        .route("/healthz", axum::routing::get(|| async { "OK" }))
        .with_state(vm.clone());

    let addr: SocketAddr = "0.0.0.0:8080".parse()?;
    println!("EU AI Pact Wasmtime Host listening on {addr}");
    axum::Server::bind(&addr).serve(app.into_make_service()).await?;
    Ok(())
}

async fn validate(
    axum::extract::State(vm): axum::extract::State<Arc<ValidatorModules>>,
    headers: HeaderMap,
    Json(req): Json<ValidationReq>,
) -> Result<Json<ValidationResp>, axum::http::StatusCode> {
    let validator = if !req.validator.is_empty() { 
        req.validator.clone() 
    } else { 
        "ai-validator".to_string() 
    };

    let module = vm.module_for(&validator)
        .map_err(|_| axum::http::StatusCode::INTERNAL_SERVER_ERROR)?;
    
    let mut store = Store::new(&vm.engine, ());
    store.add_fuel(200_000).ok();
    
    let linker = Linker::new(&vm.engine);
    let instance = linker.instantiate(&mut store, &module)
        .map_err(|_| axum::http::StatusCode::BAD_REQUEST)?;
    
    let func = instance.get_func(&mut store, "validate_compliance")
        .ok_or(axum::http::StatusCode::BAD_REQUEST)?;

    // Erwartet (i32 input_length) -> (i32 compliance_score)
    let ty = func.ty(&store);
    if ty.params() != [ValType::I32] || ty.results() != [ValType::I32] {
        return Err(axum::http::StatusCode::BAD_REQUEST);
    }

    let json_str = req.payload.to_string();
    let len = json_str.len() as i32;
    
    let result = func.call(&mut store, &[Val::I32(len)])
        .map_err(|_| axum::http::StatusCode::INTERNAL_SERVER_ERROR)?;
    
    let compliance_score = match result[0] {
        Val::I32(v) => v,
        _ => 0
    };
    
    let fuel_used = store.fuel_consumed().unwrap_or(0);
    
    let mut result_payload = req.payload;
    result_payload["validation"] = serde_json::json!({
        "validator": validator,
        "compliance_score": compliance_score,
        "fuel_consumed": fuel_used,
        "eu_ai_act_compliant": compliance_score >= 80,
        "timestamp": chrono::Utc::now().to_rfc3339()
    });

    Ok(Json(ValidationResp { 
        result: result_payload, 
        validator, 
        fuel_used, 
        compliance_score 
    }))
}
