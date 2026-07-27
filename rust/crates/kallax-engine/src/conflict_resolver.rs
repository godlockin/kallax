//! Conflict resolver for handling concurrent modifications
//!
//! Detects and resolves conflicts when multiple performers modify overlapping resources.

use chrono::{DateTime, Utc};
use dashmap::DashMap;
use kallax_core::{KallaxError, PerformerId, Result};
use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::path::PathBuf;

/// A conflict between performers
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Conflict {
    pub id: String,
    pub conflict_type: ConflictType,
    pub performer_a: PerformerId,
    pub performer_b: PerformerId,
    pub resource: String,
    pub status: ConflictStatus,
    pub detected_at: DateTime<Utc>,
    pub resolved_at: Option<DateTime<Utc>>,
    pub resolution: Option<ConflictResolution>,
}

/// Conflict types
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ConflictType {
    /// Same file modified by multiple performers
    FileConflict,
    /// Overlapping scope claimed
    ScopeOverlap,
    /// Resource contention (e.g., database lock)
    ResourceContention,
    /// Logical conflict (business logic violation)
    LogicalConflict,
}

/// Conflict status
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ConflictStatus {
    Detected,
    Investigating,
    Resolved,
    Escalated,
}

/// How a conflict was resolved
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ConflictResolution {
    /// Performer A's changes were kept
    KeepA,
    /// Performer B's changes were kept
    KeepB,
    /// Changes were merged
    Merged,
    /// One performer was asked to retry
    Retry { performer: PerformerId },
    /// Manual intervention required
    ManualIntervention,
}

/// Resource lock
#[derive(Debug, Clone)]
struct ResourceLock {
    performer_id: PerformerId,
    locked_at: DateTime<Utc>,
}

/// Conflict resolver
pub struct ConflictResolver {
    conflicts: DashMap<String, Conflict>,
    /// Resource path -> lock info
    locks: DashMap<String, ResourceLock>,
    /// Performer ID -> locked resources
    performer_locks: DashMap<String, HashSet<String>>,
    conflict_counter: std::sync::atomic::AtomicU64,
}

impl ConflictResolver {
    pub fn new() -> Self {
        Self {
            conflicts: DashMap::new(),
            locks: DashMap::new(),
            performer_locks: DashMap::new(),
            conflict_counter: std::sync::atomic::AtomicU64::new(0),
        }
    }

    /// Acquire a lock on a resource
    pub fn acquire_lock(&self, performer_id: &PerformerId, resource: &str) -> Result<()> {
        // Check if already locked by another performer
        if let Some(existing) = self.locks.get(resource) {
            if existing.performer_id.as_str() != performer_id.as_str() {
                return Err(KallaxError::InvalidState {
                    entity_type: "resource_lock",
                    entity_id: resource.to_string(),
                    expected: "unlocked".to_string(),
                    actual: format!("locked by {}", existing.performer_id),
                });
            }
            // Already locked by same performer, OK
            return Ok(());
        }

        // Acquire lock
        let lock = ResourceLock {
            performer_id: performer_id.clone(),
            locked_at: Utc::now(),
        };
        self.locks.insert(resource.to_string(), lock);

        // Track performer's locks
        self.performer_locks
            .entry(performer_id.as_str().to_string())
            .or_insert_with(HashSet::new)
            .insert(resource.to_string());

        Ok(())
    }

    /// Release a lock on a resource
    pub fn release_lock(&self, performer_id: &PerformerId, resource: &str) -> Result<()> {
        // Verify lock ownership
        if let Some(lock) = self.locks.get(resource) {
            if lock.performer_id.as_str() != performer_id.as_str() {
                return Err(KallaxError::InvalidState {
                    entity_type: "resource_lock",
                    entity_id: resource.to_string(),
                    expected: format!("locked by {}", performer_id),
                    actual: format!("locked by {}", lock.performer_id),
                });
            }
        } else {
            // Not locked, OK
            return Ok(());
        }

        // Release lock
        self.locks.remove(resource);

        // Update performer's locks
        if let Some(mut locks) = self.performer_locks.get_mut(performer_id.as_str()) {
            locks.remove(resource);
        }

        Ok(())
    }

    /// Release all locks held by a performer
    pub fn release_all_locks(&self, performer_id: &PerformerId) {
        if let Some((_, resources)) = self.performer_locks.remove(performer_id.as_str()) {
            for resource in resources {
                self.locks.remove(&resource);
            }
        }
    }

    /// Detect conflict when two performers try to access same resource
    pub fn detect_conflict(
        &self,
        performer_a: &PerformerId,
        performer_b: &PerformerId,
        resource: &str,
        conflict_type: ConflictType,
    ) -> Conflict {
        let id = format!(
            "CONFLICT-{}",
            self.conflict_counter
                .fetch_add(1, std::sync::atomic::Ordering::SeqCst)
        );

        let conflict = Conflict {
            id: id.clone(),
            conflict_type,
            performer_a: performer_a.clone(),
            performer_b: performer_b.clone(),
            resource: resource.to_string(),
            status: ConflictStatus::Detected,
            detected_at: Utc::now(),
            resolved_at: None,
            resolution: None,
        };

        self.conflicts.insert(id.clone(), conflict.clone());
        conflict
    }

    /// Resolve a conflict
    pub fn resolve_conflict(
        &self,
        conflict_id: &str,
        resolution: ConflictResolution,
    ) -> Result<()> {
        let mut conflict = self
            .conflicts
            .get_mut(conflict_id)
            .ok_or_else(|| KallaxError::not_found("conflict", conflict_id))?;

        conflict.status = ConflictStatus::Resolved;
        conflict.resolved_at = Some(Utc::now());
        conflict.resolution = Some(resolution);

        Ok(())
    }

    /// Get a conflict by ID
    pub fn get_conflict(&self, conflict_id: &str) -> Option<Conflict> {
        self.conflicts.get(conflict_id).map(|c| c.value().clone())
    }

    /// Get all active (unresolved) conflicts
    pub fn get_active_conflicts(&self) -> Vec<Conflict> {
        self.conflicts
            .iter()
            .filter(|c| c.status != ConflictStatus::Resolved)
            .map(|c| (*c.value()).clone())
            .collect()
    }

    /// Get conflicts for a performer
    pub fn get_performer_conflicts(&self, performer_id: &PerformerId) -> Vec<Conflict> {
        let id = performer_id.as_str();
        self.conflicts
            .iter()
            .filter(|c| c.performer_a.as_str() == id || c.performer_b.as_str() == id)
            .map(|c| (*c.value()).clone())
            .collect()
    }

    /// Check if a resource is locked
    pub fn is_locked(&self, resource: &str) -> bool {
        self.locks.contains_key(resource)
    }

    /// Get lock holder for a resource
    pub fn get_lock_holder(&self, resource: &str) -> Option<PerformerId> {
        self.locks
            .get(resource)
            .map(|l| l.value().performer_id.clone())
    }
}

impl Default for ConflictResolver {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn acquire_and_release_lock() {
        let resolver = ConflictResolver::new();
        let performer = PerformerId::from_str("perf-1");

        resolver.acquire_lock(&performer, "/src/main.rs").unwrap();
        assert!(resolver.is_locked("/src/main.rs"));

        resolver.release_lock(&performer, "/src/main.rs").unwrap();
        assert!(!resolver.is_locked("/src/main.rs"));
    }

    #[test]
    fn lock_prevents_concurrent_access() {
        let resolver = ConflictResolver::new();
        let perf1 = PerformerId::from_str("perf-1");
        let perf2 = PerformerId::from_str("perf-2");

        resolver.acquire_lock(&perf1, "/src/main.rs").unwrap();

        let result = resolver.acquire_lock(&perf2, "/src/main.rs");
        assert!(result.is_err());
    }

    #[test]
    fn detect_and_resolve_conflict() {
        let resolver = ConflictResolver::new();
        let perf1 = PerformerId::from_str("perf-1");
        let perf2 = PerformerId::from_str("perf-2");

        let conflict =
            resolver.detect_conflict(&perf1, &perf2, "/src/main.rs", ConflictType::FileConflict);

        assert_eq!(conflict.status, ConflictStatus::Detected);

        resolver
            .resolve_conflict(&conflict.id, ConflictResolution::KeepA)
            .unwrap();

        let resolved = resolver.get_conflict(&conflict.id).unwrap();
        assert_eq!(resolved.status, ConflictStatus::Resolved);
        assert!(matches!(
            resolved.resolution,
            Some(ConflictResolution::KeepA)
        ));
    }

    #[test]
    fn release_all_locks() {
        let resolver = ConflictResolver::new();
        let performer = PerformerId::from_str("perf-1");

        resolver.acquire_lock(&performer, "/src/a.rs").unwrap();
        resolver.acquire_lock(&performer, "/src/b.rs").unwrap();
        resolver.acquire_lock(&performer, "/src/c.rs").unwrap();

        assert!(resolver.is_locked("/src/a.rs"));
        assert!(resolver.is_locked("/src/b.rs"));
        assert!(resolver.is_locked("/src/c.rs"));

        resolver.release_all_locks(&performer);

        assert!(!resolver.is_locked("/src/a.rs"));
        assert!(!resolver.is_locked("/src/b.rs"));
        assert!(!resolver.is_locked("/src/c.rs"));
    }
}
