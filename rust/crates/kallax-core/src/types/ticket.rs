//! ## Ticket Types
//!
//! Ticket: the work unit tracked in jira/, with state machine for status transitions.
//! TicketId: opaque newtype wrapper for type-safe ticket references.
//! TicketStatus: enum of valid ticket states (follows v1.0 status flow).
//! Priority: enum of priority levels (P0-P3, lower number = higher priority).

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use super::performer::PerformerId;
use std::path::PathBuf;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Ticket {
    id: TicketId,
    title: String,
    description: String,
    status: TicketStatus,
    priority: Priority,
    scope: Vec<PathBuf>,
    acceptance_criteria: Vec<String>,
    tags: Vec<String>,
    metadata: HashMap<String, serde_json::Value>,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
    assigned_to: Option<PerformerId>,
}
impl Ticket {
    /// Create a new ticket in Ready state
    pub fn new(title: impl Into<String>, description: impl Into<String>) -> Self {
        let now = Utc::now();
        Self {
            id: TicketId::new(),
            title: title.into(),
            description: description.into(),
            status: TicketStatus::Ready,
            priority: Priority::Normal,
            scope: Vec::new(),
            acceptance_criteria: Vec::new(),
            tags: Vec::new(),
            metadata: HashMap::new(),
            created_at: now,
            updated_at: now,
            assigned_to: None,
        }
    }

    // Getters
    pub fn id(&self) -> &TicketId { &self.id }
    pub fn title(&self) -> &str { &self.title }
    pub fn description(&self) -> &str { &self.description }
    pub fn status(&self) -> TicketStatus { self.status }
    pub fn priority(&self) -> Priority { self.priority }
    pub fn scope(&self) -> &[PathBuf] { &self.scope }
    pub fn acceptance_criteria(&self) -> &[String] { &self.acceptance_criteria }
    pub fn tags(&self) -> &[String] { &self.tags }
    pub fn created_at(&self) -> DateTime<Utc> { self.created_at }
    pub fn updated_at(&self) -> DateTime<Utc> { self.updated_at }
    pub fn assigned_to(&self) -> Option<&PerformerId> { self.assigned_to.as_ref() }

    /// Return a reference to the metadata map.
    pub fn metadata(&self) -> &HashMap<String, serde_json::Value> { &self.metadata }

    /// Construct a ticket from raw storage values (used by persistence layer).
    /// Does NOT validate state transitions — assumes caller stored valid state.
    #[doc(hidden)]
    pub fn from_storage(
        id: TicketId,
        title: String,
        description: String,
        status: TicketStatus,
        priority: Priority,
        scope: Vec<PathBuf>,
        acceptance_criteria: Vec<String>,
        tags: Vec<String>,
        metadata: HashMap<String, serde_json::Value>,
        created_at: DateTime<Utc>,
        updated_at: DateTime<Utc>,
        assigned_to: Option<PerformerId>,
    ) -> Self {
        Self {
            id, title, description, status, priority,
            scope, acceptance_criteria, tags, metadata,
            created_at, updated_at, assigned_to,
        }
    }

    // Builder methods
    pub fn with_priority(mut self, priority: Priority) -> Self {
        self.priority = priority;
        self.updated_at = Utc::now();
        self
    }

    pub fn with_scope(mut self, scope: Vec<PathBuf>) -> Self {
        self.scope = scope;
        self.updated_at = Utc::now();
        self
    }

    pub fn with_acceptance_criteria(mut self, criteria: Vec<String>) -> Self {
        self.acceptance_criteria = criteria;
        self.updated_at = Utc::now();
        self
    }

    pub fn with_tags(mut self, tags: Vec<String>) -> Self {
        self.tags = tags;
        self.updated_at = Utc::now();
        self
    }

    /// Assign ticket to a performer (only if status is Ready)
    pub fn assign(&mut self, performer_id: PerformerId) -> crate::Result<()> {
        if self.status != TicketStatus::Ready {
            return Err(crate::KallaxError::invalid_state(
                "ticket",
                self.id.as_str(),
                "ready",
                self.status.as_str(),
            ));
        }
        self.assigned_to = Some(performer_id);
        self.status = TicketStatus::InProgress;
        self.updated_at = Utc::now();
        Ok(())
    }

    /// Mark ticket as completed
    pub fn complete(&mut self) -> crate::Result<()> {
        if self.status != TicketStatus::InProgress {
            return Err(crate::KallaxError::invalid_state(
                "ticket",
                self.id.as_str(),
                "in_progress",
                self.status.as_str(),
            ));
        }
        self.status = TicketStatus::Completed;
        self.updated_at = Utc::now();
        Ok(())
    }

    /// Mark ticket as failed
    pub fn fail(&mut self, _reason: impl Into<String>) -> crate::Result<()> {
        if self.status != TicketStatus::InProgress {
            return Err(crate::KallaxError::invalid_state(
                "ticket",
                self.id.as_str(),
                "in_progress",
                self.status.as_str(),
            ));
        }
        self.status = TicketStatus::Failed;
        self.updated_at = Utc::now();
        Ok(())
    }
}

/// Unique identifier for a ticket
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct TicketId(String);

impl TicketId {
    pub fn new() -> Self {
        Self(format!("TICKET-{}", Uuid::new_v4().to_string()[..8].to_uppercase()))
    }

    pub fn from_str(s: impl Into<String>) -> Self {
        Self(s.into())
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl Default for TicketId {
    fn default() -> Self {
        Self::new()
    }
}

impl std::fmt::Display for TicketId {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.0)
    }
}

/// Ticket status enum
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TicketStatus {
    Ready,
    InProgress,
    Completed,
    Failed,
    Blocked,
}

impl TicketStatus {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Ready => "ready",
            Self::InProgress => "in_progress",
            Self::Completed => "completed",
            Self::Failed => "failed",
            Self::Blocked => "blocked",
        }
    }
}

/// Priority levels
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Priority {
    Low = 0,
    Normal = 1,
    High = 2,
    Critical = 3,
}
