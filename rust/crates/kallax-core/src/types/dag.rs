//! DAG run + node state types — workflow execution tracking.
//!
//! Persisted in `dag_runs` (schema.sql:151) and `dag_node_states` (schema.sql:164).

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum DagStatus {
    Pending,
    Running,
    Completed,
    Failed,
    Cancelled,
}

impl DagStatus {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Pending => "pending",
            Self::Running => "running",
            Self::Completed => "completed",
            Self::Failed => "failed",
            Self::Cancelled => "cancelled",
        }
    }

    pub fn from_str(s: &str) -> Option<Self> {
        match s {
            "pending" => Some(Self::Pending),
            "running" => Some(Self::Running),
            "completed" => Some(Self::Completed),
            "failed" => Some(Self::Failed),
            "cancelled" => Some(Self::Cancelled),
            _ => None,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DagRun {
    id: String,
    dag_name: String,
    status: DagStatus,
    trigger: String,
    started_at: Option<DateTime<Utc>>,
    completed_at: Option<DateTime<Utc>>,
}

impl DagRun {
    pub fn new(
        id: impl Into<String>,
        dag_name: impl Into<String>,
        trigger: impl Into<String>,
    ) -> Self {
        Self {
            id: id.into(),
            dag_name: dag_name.into(),
            status: DagStatus::Pending,
            trigger: trigger.into(),
            started_at: None,
            completed_at: None,
        }
    }

    pub fn id(&self) -> &str { &self.id }
    pub fn dag_name(&self) -> &str { &self.dag_name }
    pub fn status(&self) -> DagStatus { self.status }
    pub fn trigger(&self) -> &str { &self.trigger }
    pub fn started_at(&self) -> Option<DateTime<Utc>> { self.started_at }
    pub fn completed_at(&self) -> Option<DateTime<Utc>> { self.completed_at }

    pub fn mark_running(&mut self) {
        self.status = DagStatus::Running;
        self.started_at = Some(Utc::now());
    }

    pub fn mark_completed(&mut self) {
        self.status = DagStatus::Completed;
        self.completed_at = Some(Utc::now());
    }

    pub fn mark_failed(&mut self) {
        self.status = DagStatus::Failed;
        self.completed_at = Some(Utc::now());
    }

    pub fn from_storage(
        id: String,
        dag_name: String,
        status: DagStatus,
        trigger: String,
        started_at: Option<DateTime<Utc>>,
        completed_at: Option<DateTime<Utc>>,
    ) -> Self {
        Self { id, dag_name, status, trigger, started_at, completed_at }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DagNodeState {
    id: String,
    dag_run_id: String,
    node_name: String,
    status: DagStatus,
    task_id: Option<String>,
    output: Option<String>,
    started_at: Option<DateTime<Utc>>,
    completed_at: Option<DateTime<Utc>>,
}

impl DagNodeState {
    pub fn new(
        id: impl Into<String>,
        dag_run_id: impl Into<String>,
        node_name: impl Into<String>,
    ) -> Self {
        Self {
            id: id.into(),
            dag_run_id: dag_run_id.into(),
            node_name: node_name.into(),
            status: DagStatus::Pending,
            task_id: None,
            output: None,
            started_at: None,
            completed_at: None,
        }
    }

    pub fn id(&self) -> &str { &self.id }
    pub fn dag_run_id(&self) -> &str { &self.dag_run_id }
    pub fn node_name(&self) -> &str { &self.node_name }
    pub fn status(&self) -> DagStatus { self.status }
    pub fn task_id(&self) -> Option<&str> { self.task_id.as_deref() }
    pub fn output(&self) -> Option<&str> { self.output.as_deref() }
    pub fn started_at(&self) -> Option<DateTime<Utc>> { self.started_at }
    pub fn completed_at(&self) -> Option<DateTime<Utc>> { self.completed_at }

    pub fn set_task_id(&mut self, task_id: impl Into<String>) {
        self.task_id = Some(task_id.into());
    }

    pub fn mark_running(&mut self) {
        self.status = DagStatus::Running;
        self.started_at = Some(Utc::now());
    }

    pub fn mark_completed(&mut self, output: Option<String>) {
        self.status = DagStatus::Completed;
        self.output = output;
        self.completed_at = Some(Utc::now());
    }

    pub fn mark_failed(&mut self, output: Option<String>) {
        self.status = DagStatus::Failed;
        self.output = output;
        self.completed_at = Some(Utc::now());
    }

    pub fn from_storage(
        id: String,
        dag_run_id: String,
        node_name: String,
        status: DagStatus,
        task_id: Option<String>,
        output: Option<String>,
        started_at: Option<DateTime<Utc>>,
        completed_at: Option<DateTime<Utc>>,
    ) -> Self {
        Self { id, dag_run_id, node_name, status, task_id, output, started_at, completed_at }
    }
}
