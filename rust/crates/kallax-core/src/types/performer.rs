//! ## Performer Types
//!
//! Performer: agent instance that claims and ships tasks.
//! PerformerId: opaque newtype wrapper for type-safe performer references.
//! PerformerStatus: enum of valid performer states (idle, busy, active).

use super::task::TaskId;
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;
use uuid::Uuid;

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
    pub fn id(&self) -> &PerformerId {
        &self.id
    }
    pub fn name(&self) -> &str {
        &self.name
    }
    pub fn status(&self) -> PerformerStatus {
        self.status
    }
    pub fn capabilities(&self) -> &[String] {
        &self.capabilities
    }
    pub fn scope(&self) -> &[PathBuf] {
        &self.scope
    }
    pub fn current_task(&self) -> Option<&TaskId> {
        self.current_task.as_ref()
    }
    pub fn worktree_path(&self) -> Option<&PathBuf> {
        self.worktree_path.as_ref()
    }
    pub fn heartbeat_at(&self) -> DateTime<Utc> {
        self.heartbeat_at
    }

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
            crate::KallaxError::invalid_state("performer", self.id.as_str(), "busy", "idle")
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
        Self(format!(
            "PERF-{}",
            Uuid::new_v4().to_string()[..8].to_uppercase()
        ))
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
