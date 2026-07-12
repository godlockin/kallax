//! Trace span type — structured observability event log.
//!
//! Persisted append-only in the `trace_spans` table. See db/schema.sql:68.

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

pub type SpanContext = HashMap<String, serde_json::Value>;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TraceSpan {
    id: String,
    span_name: String,
    parent_span_id: Option<String>,
    context: SpanContext,
    started_at: DateTime<Utc>,
    ended_at: Option<DateTime<Utc>>,
    duration_ms: Option<i64>,
}

impl TraceSpan {
    pub fn start(id: impl Into<String>, span_name: impl Into<String>) -> Self {
        Self {
            id: id.into(),
            span_name: span_name.into(),
            parent_span_id: None,
            context: SpanContext::new(),
            started_at: Utc::now(),
            ended_at: None,
            duration_ms: None,
        }
    }

    pub fn with_parent(mut self, parent_id: impl Into<String>) -> Self {
        self.parent_span_id = Some(parent_id.into());
        self
    }

    pub fn with_context(mut self, context: SpanContext) -> Self {
        self.context = context;
        self
    }

    pub fn end(&mut self) {
        let now = Utc::now();
        self.duration_ms = Some((now - self.started_at).num_milliseconds());
        self.ended_at = Some(now);
    }

    pub fn id(&self) -> &str { &self.id }
    pub fn span_name(&self) -> &str { &self.span_name }
    pub fn parent_span_id(&self) -> Option<&str> { self.parent_span_id.as_deref() }
    pub fn context(&self) -> &SpanContext { &self.context }
    pub fn started_at(&self) -> DateTime<Utc> { self.started_at }
    pub fn ended_at(&self) -> Option<DateTime<Utc>> { self.ended_at }
    pub fn duration_ms(&self) -> Option<i64> { self.duration_ms }

    pub fn from_storage(
        id: String,
        span_name: String,
        parent_span_id: Option<String>,
        context: SpanContext,
        started_at: DateTime<Utc>,
        ended_at: Option<DateTime<Utc>>,
        duration_ms: Option<i64>,
    ) -> Self {
        Self { id, span_name, parent_span_id, context, started_at, ended_at, duration_ms }
    }
}
