//! Core types for KALLAX multi-agent orchestration
//!
//! Types follow these principles:
//! - Immutable by default (fields are private, accessed via methods)
//! - All state transitions are explicit
//! - Serializable for persistence

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;
use uuid::Uuid;

// ─────────────────────────────────────────────────────────────────────────────
// Ticket (Work Unit)
// ─────────────────────────────────────────────────────────────────────────────

/// A ticket represents a unit of work to be completed
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

// ─────────────────────────────────────────────────────────────────────────────
// Task (Execution Unit)
// ─────────────────────────────────────────────────────────────────────────────

/// A task is an atomic execution unit derived from a ticket
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Task {
    id: TaskId,
    ticket_id: TicketId,
    task_type: TaskType,
    input: serde_json::Value,
    output: Option<serde_json::Value>,
    status: TaskStatus,
    dependencies: Vec<TaskId>,
    created_at: DateTime<Utc>,
    started_at: Option<DateTime<Utc>>,
    completed_at: Option<DateTime<Utc>>,
}

impl Task {
    pub fn new(ticket_id: TicketId, task_type: TaskType, input: serde_json::Value) -> Self {
        Self {
            id: TaskId::new(),
            ticket_id,
            task_type,
            input,
            output: None,
            status: TaskStatus::Pending,
            dependencies: Vec::new(),
            created_at: Utc::now(),
            started_at: None,
            completed_at: None,
        }
    }

    // Getters
    pub fn id(&self) -> &TaskId { &self.id }
    pub fn ticket_id(&self) -> &TicketId { &self.ticket_id }
    pub fn task_type(&self) -> TaskType { self.task_type }
    pub fn input(&self) -> &serde_json::Value { &self.input }
    pub fn output(&self) -> Option<&serde_json::Value> { self.output.as_ref() }
    pub fn status(&self) -> TaskStatus { self.status }
    pub fn dependencies(&self) -> &[TaskId] { &self.dependencies }

    /// Add dependency
    pub fn with_dependency(mut self, task_id: TaskId) -> Self {
        self.dependencies.push(task_id);
        self
    }

    /// Start task execution
    pub fn start(&mut self) -> crate::Result<()> {
        if self.status != TaskStatus::Pending {
            return Err(crate::KallaxError::invalid_state(
                "task",
                self.id.as_str(),
                "pending",
                self.status.as_str(),
            ));
        }
        self.status = TaskStatus::Running;
        self.started_at = Some(Utc::now());
        Ok(())
    }

    /// Complete task with output
    pub fn complete_with_output(&mut self, output: serde_json::Value) -> crate::Result<()> {
        if self.status != TaskStatus::Running {
            return Err(crate::KallaxError::invalid_state(
                "task",
                self.id.as_str(),
                "running",
                self.status.as_str(),
            ));
        }
        self.output = Some(output);
        self.status = TaskStatus::Completed;
        self.completed_at = Some(Utc::now());
        Ok(())
    }

    /// Fail task
    pub fn fail(&mut self) -> crate::Result<()> {
        if self.status != TaskStatus::Running {
            return Err(crate::KallaxError::invalid_state(
                "task",
                self.id.as_str(),
                "running",
                self.status.as_str(),
            ));
        }
        self.status = TaskStatus::Failed;
        self.completed_at = Some(Utc::now());
        Ok(())
    }
}

/// Unique identifier for a task
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct TaskId(String);

impl TaskId {
    pub fn new() -> Self {
        Self(format!("TASK-{}", Uuid::new_v4().to_string()[..8].to_uppercase()))
    }

    pub fn from_str(s: impl Into<String>) -> Self {
        Self(s.into())
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl Default for TaskId {
    fn default() -> Self {
        Self::new()
    }
}

impl std::fmt::Display for TaskId {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.0)
    }
}

/// Task types
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TaskType {
    Analyze,
    Generate,
    Review,
    Test,
    Deploy,
    Custom,
}

/// Task status
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TaskStatus {
    Pending,
    Running,
    Completed,
    Failed,
    Cancelled,
}

impl TaskStatus {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Pending => "pending",
            Self::Running => "running",
            Self::Completed => "completed",
            Self::Failed => "failed",
            Self::Cancelled => "cancelled",
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Performer (Agent Instance)
// ─────────────────────────────────────────────────────────────────────────────

/// A performer is an agent instance that can execute tasks
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Performer {
    id: PerformerId,
    name: String,
    status: PerformerStatus,
    capabilities: Vec<String>,
    scope: Vec<PathBuf>,
    current_task: Option<TaskId>,
    worktree_path: Option<PathBuf>,
    heartbeat_at: DateTime<Utc>,
    registered_at: DateTime<Utc>,
}

impl Performer {
    pub fn new(name: impl Into<String>) -> Self {
        let now = Utc::now();
        Self {
            id: PerformerId::new(),
            name: name.into(),
            status: PerformerStatus::Idle,
            capabilities: Vec::new(),
            scope: Vec::new(),
            current_task: None,
            worktree_path: None,
            heartbeat_at: now,
            registered_at: now,
        }
    }

    // Getters
    pub fn id(&self) -> &PerformerId { &self.id }
    pub fn name(&self) -> &str { &self.name }
    pub fn status(&self) -> PerformerStatus { self.status }
    pub fn capabilities(&self) -> &[String] { &self.capabilities }
    pub fn scope(&self) -> &[PathBuf] { &self.scope }
    pub fn current_task(&self) -> Option<&TaskId> { self.current_task.as_ref() }
    pub fn worktree_path(&self) -> Option<&PathBuf> { self.worktree_path.as_ref() }
    pub fn heartbeat_at(&self) -> DateTime<Utc> { self.heartbeat_at }

    /// Set performer capabilities
    pub fn with_capabilities(mut self, capabilities: Vec<String>) -> Self {
        self.capabilities = capabilities;
        self
    }

    /// Set performer scope (file/directory isolation)
    pub fn with_scope(mut self, scope: Vec<PathBuf>) -> Self {
        self.scope = scope;
        self
    }

    /// Set worktree path for isolation
    pub fn with_worktree(mut self, path: PathBuf) -> Self {
        self.worktree_path = Some(path);
        self
    }

    /// Assign task to performer
    pub fn assign_task(&mut self, task_id: TaskId) -> crate::Result<()> {
        if self.status != PerformerStatus::Idle {
            return Err(crate::KallaxError::invalid_state(
                "performer",
                self.id.as_str(),
                "idle",
                self.status.as_str(),
            ));
        }
        self.current_task = Some(task_id);
        self.status = PerformerStatus::Busy;
        Ok(())
    }

    /// Release task from performer
    pub fn release_task(&mut self) -> crate::Result<TaskId> {
        let task_id = self.current_task.take().ok_or_else(|| {
            crate::KallaxError::invalid_state(
                "performer",
                self.id.as_str(),
                "busy",
                "idle",
            )
        })?;
        self.status = PerformerStatus::Idle;
        Ok(task_id)
    }

    /// Update heartbeat
    pub fn heartbeat(&mut self) {
        self.heartbeat_at = Utc::now();
    }
}

/// Unique identifier for a performer
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct PerformerId(String);

impl PerformerId {
    pub fn new() -> Self {
        Self(format!("PERF-{}", Uuid::new_v4().to_string()[..8].to_uppercase()))
    }

    pub fn from_str(s: impl Into<String>) -> Self {
        Self(s.into())
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl Default for PerformerId {
    fn default() -> Self {
        Self::new()
    }
}

impl std::fmt::Display for PerformerId {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.0)
    }
}

/// Performer status
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PerformerStatus {
    Idle,
    Busy,
    Offline,
}

impl PerformerStatus {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Idle => "idle",
            Self::Busy => "busy",
            Self::Offline => "offline",
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Event
// ─────────────────────────────────────────────────────────────────────────────

/// Events emitted by the system
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
