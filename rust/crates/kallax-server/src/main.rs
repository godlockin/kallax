//! KALLAX HTTP Server - REST API for multi-agent orchestration
//!
//! Endpoints:
//! - GET /health - Health check
//! - GET /tasks - List tickets
//! - POST /tasks - Create ticket
//! - GET /tasks/:id - Get ticket
//! - PUT /tasks/:id/claim - Claim ticket
//! - PUT /tasks/:id/complete - Complete ticket
//! - GET /performers - List performers
//! - POST /performers/register - Register performer

use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::IntoResponse,
    routing::{get, post, put},
    Json, Router,
};
use kallax_core::{KallaxError, Performer, PerformerId, Priority, Ticket};
use kallax_engine::{AgentPool, ConflictResolver, DagScheduler, EventBus, KnowledgeBase, TicketEngine};
use kallax_core::TaskId;
use serde::{Deserialize, Serialize};
use std::net::SocketAddr;
use std::sync::Arc;
use tower_http::cors::{Any, CorsLayer};
use tower_http::trace::TraceLayer;
use tracing::info;
use tracing_subscriber::{fmt, prelude::*, EnvFilter};

// ─────────────────────────────────────────────────────────────────────────────
// Application State
// ─────────────────────────────────────────────────────────────────────────────

#[derive(Clone)]
struct AppState {
    engine: Arc<TicketEngine>,
    pool: Arc<AgentPool>,
    knowledge: Arc<KnowledgeBase>,
    scheduler: Arc<std::sync::Mutex<DagScheduler>>,
    conflicts: Arc<ConflictResolver>,
}

// ─────────────────────────────────────────────────────────────────────────────
// Error wrapper for orphan rules
// ─────────────────────────────────────────────────────────────────────────────

struct AppError(KallaxError);

impl From<KallaxError> for AppError {
    fn from(e: KallaxError) -> Self {
        AppError(e)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Request/Response DTOs
// ─────────────────────────────────────────────────────────────────────────────

#[derive(Debug, Deserialize)]
struct CreateTicketRequest {
    title: String,
    description: String,
    #[serde(default)]
    priority: Option<String>,
    #[serde(default)]
    scope: Option<Vec<String>>,
    #[serde(default)]
    acceptance_criteria: Option<Vec<String>>,
}

#[derive(Debug, Serialize)]
struct TicketResponse {
    id: String,
    title: String,
    description: String,
    status: String,
    priority: String,
    scope: Vec<String>,
    acceptance_criteria: Vec<String>,
    created_at: String,
    updated_at: String,
    assigned_to: Option<String>,
}

impl From<&Ticket> for TicketResponse {
    fn from(t: &Ticket) -> Self {
        Self {
            id: t.id().as_str().to_string(),
            title: t.title().to_string(),
            description: t.description().to_string(),
            status: t.status().as_str().to_string(),
            priority: format!("{:?}", t.priority()).to_lowercase(),
            scope: t.scope().iter().map(|p| p.display().to_string()).collect(),
            acceptance_criteria: t.acceptance_criteria().to_vec(),
            created_at: t.created_at().to_rfc3339(),
            updated_at: t.updated_at().to_rfc3339(),
            assigned_to: t.assigned_to().map(|p| p.as_str().to_string()),
        }
    }
}

#[derive(Debug, Deserialize)]
struct ClaimTicketRequest {
    performer_id: String,
}

#[derive(Debug, Deserialize)]
struct RegisterPerformerRequest {
    name: String,
    #[serde(default)]
    capabilities: Option<Vec<String>>,
}

#[derive(Debug, Serialize)]
struct PerformerResponse {
    id: String,
    name: String,
    status: String,
    capabilities: Vec<String>,
    current_task: Option<String>,
    heartbeat_at: String,
}

impl From<&Performer> for PerformerResponse {
    fn from(p: &Performer) -> Self {
        Self {
            id: p.id().as_str().to_string(),
            name: p.name().to_string(),
            status: p.status().as_str().to_string(),
            capabilities: p.capabilities().to_vec(),
            current_task: p.current_task().map(|t| t.as_str().to_string()),
            heartbeat_at: p.heartbeat_at().to_rfc3339(),
        }
    }
}

#[derive(Debug, Serialize)]
struct ErrorResponse {
    error: String,
    message: String,
}

#[derive(Debug, Serialize)]
struct HealthResponse {
    status: String,
    version: String,
    timestamp: String,
}

#[derive(Debug, Serialize)]
struct StatsResponse {
    tickets: TicketStats,
    performers: PerformerStats,
}

#[derive(Debug, Serialize)]
struct TicketStats {
    total: usize,
    ready: usize,
    in_progress: usize,
    completed: usize,
}

#[derive(Debug, Serialize)]
struct PerformerStats {
    total: usize,
    idle: usize,
    busy: usize,
}

// ─────────────────────────────────────────────────────────────────────────────
// Error Handling
// ─────────────────────────────────────────────────────────────────────────────

impl IntoResponse for AppError {
    fn into_response(self) -> axum::response::Response {
        let (status, error_type) = match &self.0 {
            KallaxError::NotFound { .. } => (StatusCode::NOT_FOUND, "not_found"),
            KallaxError::AlreadyExists { .. } => (StatusCode::CONFLICT, "already_exists"),
            KallaxError::InvalidState { .. } => (StatusCode::BAD_REQUEST, "invalid_state"),
            KallaxError::Validation { .. } => (StatusCode::BAD_REQUEST, "validation_error"),
            KallaxError::ResourceExhausted { .. } => (StatusCode::SERVICE_UNAVAILABLE, "resource_exhausted"),
            _ => (StatusCode::INTERNAL_SERVER_ERROR, "internal_error"),
        };

        let body = Json(ErrorResponse {
            error: error_type.to_string(),
            message: self.0.to_string(),
        });

        (status, body).into_response()
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Handlers
// ─────────────────────────────────────────────────────────────────────────────

async fn health_check() -> Json<HealthResponse> {
    Json(HealthResponse {
        status: "healthy".to_string(),
        version: env!("CARGO_PKG_VERSION").to_string(),
        timestamp: chrono::Utc::now().to_rfc3339(),
    })
}

async fn get_stats(State(state): State<AppState>) -> Json<StatsResponse> {
    let engine_stats = state.engine.stats();
    let pool_stats = state.pool.stats();

    Json(StatsResponse {
        tickets: TicketStats {
            total: engine_stats.total_tickets,
            ready: engine_stats.ready_tickets,
            in_progress: engine_stats.in_progress_tickets,
            completed: engine_stats.completed_tickets,
        },
        performers: PerformerStats {
            total: pool_stats.total,
            idle: pool_stats.idle,
            busy: pool_stats.busy,
        },
    })
}

async fn list_tickets(
    State(state): State<AppState>,
) -> std::result::Result<Json<Vec<TicketResponse>>, AppError> {
    let tickets = state.engine.list_tickets(None);
    let response: Vec<TicketResponse> = tickets.iter().map(TicketResponse::from).collect();
    Ok(Json(response))
}

async fn create_ticket(
    State(state): State<AppState>,
    Json(payload): Json<CreateTicketRequest>,
) -> std::result::Result<(StatusCode, Json<TicketResponse>), AppError> {
    let mut ticket = Ticket::new(payload.title, payload.description);

    if let Some(priority_str) = payload.priority {
        let priority = match priority_str.to_lowercase().as_str() {
            "low" => Priority::Low,
            "high" => Priority::High,
            "critical" => Priority::Critical,
            _ => Priority::Normal,
        };
        ticket = ticket.with_priority(priority);
    }

    if let Some(scope) = payload.scope {
        ticket = ticket.with_scope(scope.into_iter().map(std::path::PathBuf::from).collect());
    }

    if let Some(criteria) = payload.acceptance_criteria {
        ticket = ticket.with_acceptance_criteria(criteria);
    }

    let id = state.engine.create_ticket(ticket.clone())?;
    let created = state.engine.get_ticket(id.as_str())?;

    Ok((StatusCode::CREATED, Json(TicketResponse::from(&created))))
}

async fn get_ticket(
    State(state): State<AppState>,
    Path(ticket_id): Path<String>,
) -> std::result::Result<Json<TicketResponse>, AppError> {
    let ticket = state.engine.get_ticket(&ticket_id)?;
    Ok(Json(TicketResponse::from(&ticket)))
}

async fn claim_ticket(
    State(state): State<AppState>,
    Path(ticket_id): Path<String>,
    Json(payload): Json<ClaimTicketRequest>,
) -> std::result::Result<Json<TicketResponse>, AppError> {
    let performer_id = PerformerId::from_str(payload.performer_id);
    state.engine.claim_ticket(&ticket_id, &performer_id)?;

    let ticket = state.engine.get_ticket(&ticket_id)?;
    Ok(Json(TicketResponse::from(&ticket)))
}

async fn complete_ticket(
    State(state): State<AppState>,
    Path(ticket_id): Path<String>,
) -> std::result::Result<Json<TicketResponse>, AppError> {
    state.engine.complete_ticket(&ticket_id)?;

    let ticket = state.engine.get_ticket(&ticket_id)?;
    Ok(Json(TicketResponse::from(&ticket)))
}

async fn list_performers(
    State(state): State<AppState>,
) -> std::result::Result<Json<Vec<PerformerResponse>>, AppError> {
    let performers = state.pool.list();
    let response: Vec<PerformerResponse> = performers.iter().map(PerformerResponse::from).collect();
    Ok(Json(response))
}

async fn register_performer(
    State(state): State<AppState>,
    Json(payload): Json<RegisterPerformerRequest>,
) -> std::result::Result<(StatusCode, Json<PerformerResponse>), AppError> {
    let mut performer = Performer::new(payload.name);

    if let Some(capabilities) = payload.capabilities {
        performer = performer.with_capabilities(capabilities);
    }

    let id = state.pool.register(performer.clone())?;
    state.engine.register_performer(performer)?;

    let registered = state.pool.get(id.as_str())
        .ok_or_else(|| KallaxError::internal("Failed to retrieve registered performer"))?;

    Ok((StatusCode::CREATED, Json(PerformerResponse::from(&registered))))
}

async fn performer_heartbeat(
    State(state): State<AppState>,
    Path(performer_id): Path<String>,
) -> std::result::Result<Json<serde_json::Value>, AppError> {
    state.pool.heartbeat(&performer_id)?;
    state.engine.heartbeat(&performer_id)?;

    Ok(Json(serde_json::json!({
        "performer_id": performer_id,
        "timestamp": chrono::Utc::now().to_rfc3339()
    })))
}

// ─────────────────────────────────────────────────────────────────────────────
// Main
// ─────────────────────────────────────────────────────────────────────────────

fn init_logging() {
    let filter = EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| EnvFilter::new("info"));

    tracing_subscriber::registry()
        .with(fmt::layer())
        .with(filter)
        .init();
}

fn create_router(state: AppState) -> Router {
    Router::new()
        // Health
        .route("/health", get(health_check))
        .route("/stats", get(get_stats))
        // Tickets/Tasks
        .route("/tasks", get(list_tickets).post(create_ticket))
        .route("/tasks/:id", get(get_ticket))
        .route("/tasks/:id/claim", put(claim_ticket))
        .route("/tasks/:id/complete", put(complete_ticket))
        // Performers
        .route("/performers", get(list_performers))
        .route("/performers/register", post(register_performer))
        .route("/performers/:id/heartbeat", put(performer_heartbeat))
        // Bridge status — proves Rust engine is alive and responsive
        .route("/bridge/status", get(bridge_status))
        .route("/bridge/scheduler", get(scheduler_status))
        // (duplicate stats removed)
        // Middleware
        .layer(TraceLayer::new_for_http())
        .layer(CorsLayer::new().allow_origin("http://localhost:9877".parse::<axum::http::HeaderValue>().unwrap()))
        .with_state(state)
}

// ── Bridge Handlers ────────────────────────────────────────────────────────

async fn bridge_status(State(state): State<AppState>) -> impl IntoResponse {
    let engine_stats = state.engine.stats();
    let pool_stats = state.pool.stats();
    let kb_count = state.knowledge.len();
    let conflict_count = state.conflicts.get_active_conflicts().len();
    Json(serde_json::json!({
        "status": "ok",
        "modules": {
            "ticket_engine": { "tickets": engine_stats.total_tickets, "tasks": engine_stats.total_tasks },
            "agent_pool": { "performers": pool_stats.total, "idle": pool_stats.idle },
            "knowledge_base": { "entries": kb_count },
            "scheduler": { "status": "active" },
            "conflict_resolver": { "active_conflicts": conflict_count }
        }
    }))
}

async fn scheduler_status(State(state): State<AppState>) -> Result<Json<serde_json::Value>, AppError> {
    // 跟 v2.7.4 D6.6 联合, 跟 Rule 8 联合, 跟'不埋坑' 5 原则 联合
    // 跟 v2.7.4 check-anti-patterns.sh 联合: unwrap 改 Result, 治根 panic 风险
    let mut s = state.scheduler.lock().map_err(|e| {
        AppError(kallax_core::error::KallaxError::lock_poisoned(
            "scheduler_status",
            format!("scheduler mutex poisoned: {}", e),
        ))
    })?;
    let ready = s.get_ready_tasks();
    let critical = s.critical_path();
    Ok(Json(serde_json::json!({
        "ready_tasks": ready.len(),
        "critical_path_length": critical.len(),
    })))
}

// ── Main ───────────────────────────────────────────────────────────────────

#[tokio::main]
async fn main() -> std::result::Result<(), Box<dyn std::error::Error>> {
    init_logging();

    // Initialize components
    let event_bus = Arc::new(EventBus::new(1024));
    let engine = Arc::new(TicketEngine::new(event_bus.clone()));
    let pool = Arc::new(AgentPool::default());
    let knowledge = Arc::new(KnowledgeBase::new());
    let scheduler = Arc::new(std::sync::Mutex::new(DagScheduler::new()));
    let conflicts = Arc::new(ConflictResolver::default());

    let state = AppState { engine, pool, knowledge, scheduler, conflicts };
    let app = create_router(state);

    // Get port from env or default
    let port: u16 = std::env::var("KALLAX_PORT")
        .ok()
        .and_then(|p| p.parse().ok())
        .unwrap_or(3000);

    let addr = SocketAddr::from(([127, 0, 0, 1], port));
    info!("KALLAX server starting on {}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app).await?;

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::body::Body;
    use axum::http::Request;
    use tower::ServiceExt;

    fn create_test_app() -> Router {
        let event_bus = Arc::new(EventBus::new(16));
        let engine = Arc::new(TicketEngine::new(event_bus));
        let pool = Arc::new(AgentPool::default());

        let knowledge = Arc::new(KnowledgeBase::new());
        let scheduler = Arc::new(std::sync::Mutex::new(DagScheduler::new()));
        let conflicts = Arc::new(ConflictResolver::default());
        create_router(AppState { engine, pool, knowledge, scheduler, conflicts })
    }

    #[tokio::test]
    async fn health_check_returns_healthy() {
        let app = create_test_app();

        let response = app
            .oneshot(Request::builder().uri("/health").body(Body::empty()).unwrap())
            .await
            .unwrap();

        assert_eq!(response.status(), StatusCode::OK);
    }
}
