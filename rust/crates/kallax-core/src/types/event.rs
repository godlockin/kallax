//! ## Event Types
//!
//! Event: structured observability event for audit + tracing.
//! EventId: opaque newtype wrapper for type-safe event references.
//! EventType: enum of event categories (task, instance, system).

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Event {
    pub id: EventId,
    pub event_type: EventType,
    pub payload: serde_json::Value,
    pub timestamp: DateTime<Utc>,
}
impl Event {
    pub fn new(event_type: EventType, payload: serde_json::Value) -> Self {
        Self {
            id: EventId::new(),
            event_type,
            payload,
            timestamp: Utc::now(),
        }
    }
}

/// Event ID
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct EventId(String);

impl EventId {
    pub fn new() -> Self {
        Self(format!("EVT-{}", Uuid::new_v4().to_string()[..8].to_uppercase()))
    }
}

impl Default for EventId {
    fn default() -> Self {
        Self::new()
    }
}

/// Event types
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum EventType {
    TicketCreated,
    TicketAssigned,
    TicketCompleted,
    TicketFailed,
    TaskStarted,
    TaskCompleted,
    TaskFailed,
    PerformerRegistered,
    PerformerHeartbeat,
    PerformerOffline,
    ConflictDetected,
    IsolationViolation,
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{Ticket, TicketId, TicketStatus, PerformerId, Task, TaskType};

    #[test]
    fn ticket_state_transitions() {
        let mut ticket = Ticket::new("Test ticket", "Description");
        assert_eq!(ticket.status(), TicketStatus::Ready);

        let performer_id = PerformerId::new();
        ticket.assign(performer_id).expect("assign should succeed");
        assert_eq!(ticket.status(), TicketStatus::InProgress);

        ticket.complete().expect("complete should succeed");
        assert_eq!(ticket.status(), TicketStatus::Completed);
    }

    #[test]
    fn invalid_state_transitions_return_error() {
        let mut ticket = Ticket::new("Test ticket", "Description");

        // Can't complete a ticket that hasn't started
        let result = ticket.complete();
        assert!(result.is_err());
    }

    #[test]
    fn task_dependencies() {
        let ticket_id = TicketId::new();
        let task1 = Task::new(ticket_id.clone(), TaskType::Analyze, serde_json::json!({}));
        let task2 = Task::new(ticket_id, TaskType::Generate, serde_json::json!({}))
            .with_dependency(task1.id().clone());

        assert_eq!(task2.dependencies().len(), 1);
        assert_eq!(task2.dependencies()[0], *task1.id());
    }
}
