//! ## Task Types
//!
//! Task: atomic work unit within a ticket (analyze, generate, verify, etc.).
//! TaskId: opaque newtype wrapper for type-safe task references.
//! TaskType: enum of task categories (Analyze, Generate, Verify, Execute).
//! TaskStatus: enum of valid task states (follows v1.0 status flow).

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use super::ticket::TicketId;
use std::path::PathBuf;
use uuid::Uuid;

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
