//! Instance types for orchestrator registry (Conductor / Performer).
//!
//! Persisted in the `instances` table. See db/schema.sql:42.

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

pub type InstanceMetadata = HashMap<String, serde_json::Value>;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum InstanceRole {
    Conductor,
    Performer,
}

impl InstanceRole {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Conductor => "conductor",
            Self::Performer => "performer",
        }
    }

    pub fn from_str(s: &str) -> Option<Self> {
        match s {
            "conductor" => Some(Self::Conductor),
            "performer" => Some(Self::Performer),
            _ => None,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Instance {
    id: String,
    name: String,
    role: InstanceRole,
    status: String,
    metadata: InstanceMetadata,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
}

impl Instance {
    pub fn new(id: impl Into<String>, name: impl Into<String>, role: InstanceRole) -> Self {
        let now = Utc::now();
        Self {
            id: id.into(),
            name: name.into(),
            role,
            status: "idle".to_string(),
            metadata: InstanceMetadata::new(),
            created_at: now,
            updated_at: now,
        }
    }

    pub fn id(&self) -> &str { &self.id }
    pub fn name(&self) -> &str { &self.name }
    pub fn role(&self) -> InstanceRole { self.role }
    pub fn status(&self) -> &str { &self.status }
    pub fn metadata(&self) -> &InstanceMetadata { &self.metadata }
    pub fn created_at(&self) -> DateTime<Utc> { self.created_at }
    pub fn updated_at(&self) -> DateTime<Utc> { self.updated_at }

    pub fn set_status(&mut self, status: impl Into<String>) {
        self.status = status.into();
        self.updated_at = Utc::now();
    }

    pub fn set_metadata(&mut self, metadata: InstanceMetadata) {
        self.metadata = metadata;
        self.updated_at = Utc::now();
    }

    /// Reconstruct from persisted storage (used by DB layer).
    pub fn from_storage(
        id: String,
        name: String,
        role: InstanceRole,
        status: String,
        metadata: InstanceMetadata,
        created_at: DateTime<Utc>,
        updated_at: DateTime<Utc>,
    ) -> Self {
        Self { id, name, role, status, metadata, created_at, updated_at }
    }
}
