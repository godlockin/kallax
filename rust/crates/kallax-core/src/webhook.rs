//! Webhook management for KALLAX event delivery
//!
//! Supports registering webhook endpoints and delivering events with
//! exponential backoff retry (2^n minutes, max 12 retries).
//! All deliveries are made concurrently via tokio tasks.

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::Mutex;
use tracing::{error, info, warn};

use crate::{KallaxError, Result};

// ─────────────────────────────────────────────────────────────────────────────
// Event types
// ─────────────────────────────────────────────────────────────────────────────

/// Webhook event types — subset of system events available for subscription
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum WebhookEvent {
    TicketCreated,
    TicketAssigned,
    TicketCompleted,
    TaskStarted,
    TaskCompleted,
    TaskFailed,
    PerformerRegistered,
}

impl WebhookEvent {
    /// Return the dot-separated string representation
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::TicketCreated => "ticket.created",
            Self::TicketAssigned => "ticket.assigned",
            Self::TicketCompleted => "ticket.completed",
            Self::TaskStarted => "task.started",
            Self::TaskCompleted => "task.completed",
            Self::TaskFailed => "task.failed",
            Self::PerformerRegistered => "performer.registered",
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Identifiers
// ─────────────────────────────────────────────────────────────────────────────

/// Unique identifier for a registered webhook endpoint
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct EndpointId(String);

impl EndpointId {
    pub fn new() -> Self {
        Self(format!(
            "EP-{}",
            uuid::Uuid::new_v4().to_string()[..8].to_uppercase()
        ))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl Default for EndpointId {
    fn default() -> Self {
        Self::new()
    }
}

impl std::fmt::Display for EndpointId {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.0)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data types
// ─────────────────────────────────────────────────────────────────────────────

/// Configuration for a registered webhook endpoint
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WebhookEndpoint {
    id: EndpointId,
    url: String,
    secret: String,
    events: Vec<WebhookEvent>,
    created_at: DateTime<Utc>,
}

impl WebhookEndpoint {
    pub fn id(&self) -> &EndpointId {
        &self.id
    }

    pub fn url(&self) -> &str {
        &self.url
    }

    pub fn events(&self) -> &[WebhookEvent] {
        &self.events
    }
}

/// Status of a single delivery attempt
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum DeliveryStatus {
    Success,
    Pending,
    Failed,
}

/// Record of a single delivery attempt (persisted for audit)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeliveryLog {
    pub event_id: String,
    pub endpoint_id: EndpointId,
    pub event_type: WebhookEvent,
    pub status: DeliveryStatus,
    pub attempt: u32,
    pub error: Option<String>,
    pub timestamp: DateTime<Utc>,
}

/// Aggregate result of delivering an event to one endpoint (all retries)
#[derive(Debug, Clone)]
pub struct DeliveryResult {
    pub endpoint_id: EndpointId,
    pub success: bool,
    pub attempts: u32,
    pub error: Option<String>,
}

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

/// Maximum number of delivery attempts (initial + up to 11 retries)
const DEFAULT_MAX_RETRIES: u32 = 12;

/// HTTP request timeout per attempt
const HTTP_TIMEOUT_SECS: u64 = 30;

// ─────────────────────────────────────────────────────────────────────────────
// WebhookManager
// ─────────────────────────────────────────────────────────────────────────────

/// Manages webhook endpoint registration and concurrent event delivery.
///
/// Design:
/// - Endpoints are stored in a thread-safe DashMap
/// - Delivery logs are append-only, guarded by a tokio Mutex
/// - Each endpoint delivery runs in its own tokio task for concurrency
/// - Failed deliveries are retried with 2^n minute exponential backoff
pub struct WebhookManager {
    endpoints: Arc<dashmap::DashMap<EndpointId, WebhookEndpoint>>,
    delivery_logs: Arc<Mutex<Vec<DeliveryLog>>>,
    client: reqwest::Client,
    max_retries: u32,
}

impl WebhookManager {
    /// Create a new WebhookManager with default retry settings
    pub fn new() -> Result<Self> {
        let client = reqwest::Client::builder()
            .timeout(Duration::from_secs(HTTP_TIMEOUT_SECS))
            .build()
            .map_err(|e| KallaxError::internal(format!("failed to build HTTP client: {e}")))?;

        Ok(Self {
            endpoints: Arc::new(dashmap::DashMap::new()),
            delivery_logs: Arc::new(Mutex::new(Vec::new())),
            client,
            max_retries: DEFAULT_MAX_RETRIES,
        })
    }

    /// Register a new webhook endpoint.
    ///
    /// Returns a unique `EndpointId` that can be used to identify the endpoint
    /// in delivery logs and results.
    pub fn register_endpoint(
        &self,
        url: impl Into<String>,
        secret: impl Into<String>,
        events: Vec<WebhookEvent>,
    ) -> EndpointId {
        let id = EndpointId::new();
        let endpoint = WebhookEndpoint {
            id: id.clone(),
            url: url.into(),
            secret: secret.into(),
            events,
            created_at: Utc::now(),
        };
        self.endpoints.insert(id.clone(), endpoint);
        id
    }

    /// Deliver an event to all subscribed endpoints concurrently.
    ///
    /// Each endpoint delivery (with retries) runs in a separate tokio task.
    /// Returns a `DeliveryResult` per endpoint indicating final outcome.
    pub async fn deliver(
        &self,
        event_type: WebhookEvent,
        payload: serde_json::Value,
    ) -> Result<Vec<DeliveryResult>> {
        let event_id = format!(
            "EVT-{}",
            uuid::Uuid::new_v4().to_string()[..8].to_uppercase()
        );

        // Collect matching endpoints while holding the read lock briefly
        let endpoints: Vec<WebhookEndpoint> = self
            .endpoints
            .iter()
            .filter(|entry| entry.value().events.contains(&event_type))
            .map(|entry| entry.value().clone())
            .collect();

        if endpoints.is_empty() {
            return Ok(Vec::new());
        }

        // Spawn a concurrent task per endpoint
        let mut handles = Vec::with_capacity(endpoints.len());
        for endpoint in endpoints {
            let client = self.client.clone();
            let max_retries = self.max_retries;
            let logs = Arc::clone(&self.delivery_logs);
            let eid = event_id.clone();
            let payload = payload.clone();

            handles.push(tokio::spawn(async move {
                Self::deliver_with_retry(
                    &client,
                    &endpoint,
                    &eid,
                    &event_type,
                    &payload,
                    max_retries,
                    &logs,
                )
                .await
            }));
        }

        // Collect results
        let mut results = Vec::with_capacity(handles.len());
        for handle in handles {
            match handle.await {
                Ok(r) => results.push(r),
                Err(join_err) => {
                    error!("webhook delivery task panicked: {join_err}");
                }
            }
        }

        Ok(results)
    }

    /// Attempt delivery with exponential backoff retries.
    ///
    /// Backoff schedule: attempt N waits 2^N minutes before retry.
    /// - attempt 0: initial send (no delay)
    /// - attempt 1: wait 2^0 = 1 minute
    /// - attempt 2: wait 2^1 = 2 minutes
    /// - attempt N (N >= 1): wait 2^(N-1) minutes
    async fn deliver_with_retry(
        client: &reqwest::Client,
        endpoint: &WebhookEndpoint,
        event_id: &str,
        event_type: &WebhookEvent,
        payload: &serde_json::Value,
        max_retries: u32,
        logs: &Mutex<Vec<DeliveryLog>>,
    ) -> DeliveryResult {
        let mut last_error: Option<String> = None;
        let endpoint_id = endpoint.id.clone();
        let url = endpoint.url.clone();

        for attempt in 0..max_retries {
            match Self::send_request(client, endpoint, event_type, payload).await {
                Ok(()) => {
                    let log = DeliveryLog {
                        event_id: event_id.to_string(),
                        endpoint_id: endpoint_id.clone(),
                        event_type: *event_type,
                        status: DeliveryStatus::Success,
                        attempt,
                        error: None,
                        timestamp: Utc::now(),
                    };
                    let mut guard = logs.lock().await;
                    guard.push(log);

                    info!(
                        "webhook delivered to {} (event: {}, attempt: {})",
                        url,
                        event_type.as_str(),
                        attempt + 1,
                    );
                    return DeliveryResult {
                        endpoint_id: endpoint_id.clone(),
                        success: true,
                        attempts: attempt + 1,
                        error: None,
                    };
                }
                Err(e) => {
                    let log = DeliveryLog {
                        event_id: event_id.to_string(),
                        endpoint_id: endpoint_id.clone(),
                        event_type: *event_type,
                        status: DeliveryStatus::Failed,
                        attempt,
                        error: Some(e.clone()),
                        timestamp: Utc::now(),
                    };
                    let mut guard = logs.lock().await;
                    guard.push(log);

                    last_error = Some(e.clone());
                    warn!(
                        "webhook delivery failed for {} (attempt: {}, sleep {}min): {}",
                        url,
                        attempt + 1,
                        2u64.pow(attempt),
                        e,
                    );

                    // Exponential backoff: 2^attempt minutes before next retry
                    let delay_secs = 60u64 * 2u64.pow(attempt);
                    tokio::time::sleep(Duration::from_secs(delay_secs)).await;
                }
            }
        }

        error!(
            "webhook delivery permanently failed for {} after {} attempts",
            url, max_retries,
        );
        DeliveryResult {
            endpoint_id,
            success: false,
            attempts: max_retries,
            error: last_error,
        }
    }

    /// Send a single HTTP POST to a webhook endpoint.
    ///
    /// Builds a JSON body with event metadata and signs it with an
    /// HMAC-like SHA256 signature using the endpoint secret.
    async fn send_request(
        client: &reqwest::Client,
        endpoint: &WebhookEndpoint,
        event_type: &WebhookEvent,
        payload: &serde_json::Value,
    ) -> std::result::Result<(), String> {
        let body = serde_json::json!({
            "event_type": event_type.as_str(),
            "payload": payload,
            "timestamp": Utc::now().to_rfc3339(),
        });

        let body_str =
            serde_json::to_string(&body).map_err(|e| format!("failed to serialize body: {e}"))?;

        // Compute signature: SHA256(body + ":" + secret)
        let sign_data = format!("{}:{}", body_str, endpoint.secret);
        let signature = format!("sha256={:x}", Sha256::digest(sign_data.as_bytes()));

        let response = client
            .post(&endpoint.url)
            .header("Content-Type", "application/json")
            .header("X-Webhook-Signature", &signature)
            .header("X-Event-Type", event_type.as_str())
            .body(body_str)
            .send()
            .await
            .map_err(|e| format!("request failed: {e}"))?;

        if !response.status().is_success() {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            return Err(format!("HTTP {}: {}", status, body));
        }

        Ok(())
    }

    /// Return all recorded delivery logs
    pub async fn delivery_logs(&self) -> Vec<DeliveryLog> {
        let guard = self.delivery_logs.lock().await;
        guard.clone()
    }

    /// Number of registered endpoints
    pub fn endpoint_count(&self) -> usize {
        self.endpoints.len()
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn endpoint_id_is_unique_and_prefixed() {
        let id = EndpointId::new();
        assert!(id.as_str().starts_with("EP-"));
        assert_eq!(id.as_str().len(), 11); // "EP-" + 8 hex chars
    }

    #[test]
    fn webhook_event_as_str_returns_correct_labels() {
        assert_eq!(WebhookEvent::TicketCreated.as_str(), "ticket.created");
        assert_eq!(WebhookEvent::TicketAssigned.as_str(), "ticket.assigned");
        assert_eq!(WebhookEvent::TicketCompleted.as_str(), "ticket.completed");
        assert_eq!(WebhookEvent::TaskStarted.as_str(), "task.started");
        assert_eq!(WebhookEvent::TaskCompleted.as_str(), "task.completed");
        assert_eq!(WebhookEvent::TaskFailed.as_str(), "task.failed");
        assert_eq!(
            WebhookEvent::PerformerRegistered.as_str(),
            "performer.registered"
        );
    }

    #[test]
    fn register_endpoint_returns_valid_id() {
        let manager = WebhookManager::new().expect("should create manager");
        let id = manager.register_endpoint(
            "https://example.com/hook",
            "sekret",
            vec![WebhookEvent::TicketCreated],
        );
        assert_eq!(manager.endpoint_count(), 1);
        assert!(id.as_str().starts_with("EP-"));
    }

    #[test]
    fn register_endpoint_with_multiple_events() {
        let manager = WebhookManager::new().expect("should create manager");
        let id = manager.register_endpoint(
            "https://example.com/hook",
            "sekret",
            vec![
                WebhookEvent::TicketCreated,
                WebhookEvent::TicketCompleted,
                WebhookEvent::TaskFailed,
            ],
        );
        assert_eq!(manager.endpoint_count(), 1);

        let ep = manager.endpoints.get(&id).expect("endpoint should exist");
        assert_eq!(ep.events().len(), 3);
    }

    #[test]
    fn endpoint_display_uses_id_string() {
        let id = EndpointId::new();
        let display = format!("{id}");
        assert_eq!(display, id.as_str());
    }
}
