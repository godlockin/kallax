//! Agent pool for performer management
//!
//! Manages performer lifecycle and allocation.

use chrono::{DateTime, Duration, Utc};
use dashmap::DashMap;
use kallax_core::{KallaxError, Performer, PerformerId, PerformerStatus, Result, TaskId};
use std::sync::Arc;
use tracing::{info, warn};

/// Agent pool configuration
#[derive(Debug, Clone)]
pub struct AgentPoolConfig {
    /// Heartbeat timeout duration
    pub heartbeat_timeout: Duration,
    /// Maximum performers allowed
    pub max_performers: usize,
}

impl Default for AgentPoolConfig {
    fn default() -> Self {
        Self {
            heartbeat_timeout: Duration::seconds(60),
            max_performers: 100,
        }
    }
}

/// Agent pool manages performer lifecycle
pub struct AgentPool {
    performers: DashMap<String, Performer>,
    config: AgentPoolConfig,
}

impl AgentPool {
    /// Create a new agent pool with config
    pub fn new(config: AgentPoolConfig) -> Self {
        Self {
            performers: DashMap::new(),
            config,
        }
    }

    /// Register a new performer
    pub fn register(&self, performer: Performer) -> Result<PerformerId> {
        let id = performer.id().clone();
        let id_str = id.as_str().to_string();

        // Check capacity
        if self.performers.len() >= self.config.max_performers {
            return Err(KallaxError::ResourceExhausted {
                resource: "performer_slots",
                limit: self.config.max_performers as u64,
                requested: 1,
            });
        }

        // Check for duplicate
        if self.performers.contains_key(&id_str) {
            return Err(KallaxError::AlreadyExists {
                entity_type: "performer",
                entity_id: id_str,
            });
        }

        let _ = self.performers.insert(id_str.clone(), performer);
        info!(performer_id = %id_str, "Performer registered in pool");

        Ok(id)
    }

    /// Unregister a performer
    pub fn unregister(&self, performer_id: &str) -> Result<Performer> {
        self.performers
            .remove(performer_id)
            .map(|(_, p)| p)
            .ok_or_else(|| KallaxError::not_found("performer", performer_id))
    }

    /// Get a performer by ID
    pub fn get(&self, performer_id: &str) -> Option<Performer> {
        self.performers.get(performer_id).map(|p| p.value().clone())
    }

    /// Update performer heartbeat
    pub fn heartbeat(&self, performer_id: &str) -> Result<()> {
        let mut performer = self
            .performers
            .get_mut(performer_id)
            .ok_or_else(|| KallaxError::not_found("performer", performer_id))?;

        performer.heartbeat();
        Ok(())
    }

    /// Get all idle performers
    pub fn get_idle_performers(&self) -> Vec<Performer> {
        self.performers
            .iter()
            .filter(|p| p.status() == PerformerStatus::Idle)
            .map(|p| (*p.value()).clone())
            .collect()
    }

    /// Get an idle performer with required capabilities
    ///
    /// EPIC-070-B6: 修复 reserve 悖论 — 原实现 assign_task + clone + release_task 等于"只查询",
    /// pool 状态没真正改变, 多并发场景会反复分配同一 performer。
    /// 新语义: 真正 reserve (assign_task), 返回时 caller 必须显式 release (acquired.release_task())
    /// 或 commit_task 才会永久占用。
    pub fn acquire_performer(&self, required_capabilities: &[String]) -> Option<Performer> {
        for mut entry in self.performers.iter_mut() {
            if entry.status() == PerformerStatus::Idle {
                let has_all_caps = required_capabilities
                    .iter()
                    .all(|cap| entry.capabilities().contains(cap));
                if has_all_caps || required_capabilities.is_empty() {
                    // 真正 reserve — 在 pool 标记为 Busy, caller 必须 release/commit_task
                    entry.assign_task(TaskId::from_str("reserved"));
                    return Some(entry.value().clone());
                }
            }
        }
        None
    }

    /// Mark stale performers as offline
    pub fn sweep_stale_performers(&self) -> Vec<PerformerId> {
        let now = Utc::now();
        let timeout = self.config.heartbeat_timeout;
        let mut marked_offline = Vec::new();

        for mut entry in self.performers.iter_mut() {
            let last_heartbeat = entry.heartbeat_at();
            if now.signed_duration_since(last_heartbeat) > timeout {
                // Mark as offline (we can't directly modify status, so we track IDs)
                marked_offline.push(entry.id().clone());
                warn!(
                    performer_id = %entry.id(),
                    last_heartbeat = %last_heartbeat,
                    "Performer marked as stale"
                );
            }
        }

        marked_offline
    }

    /// Get pool statistics
    pub fn stats(&self) -> AgentPoolStats {
        let total = self.performers.len();
        let idle = self
            .performers
            .iter()
            .filter(|p| p.status() == PerformerStatus::Idle)
            .count();
        let busy = self
            .performers
            .iter()
            .filter(|p| p.status() == PerformerStatus::Busy)
            .count();
        let offline = self
            .performers
            .iter()
            .filter(|p| p.status() == PerformerStatus::Offline)
            .count();

        AgentPoolStats {
            total,
            idle,
            busy,
            offline,
            max_capacity: self.config.max_performers,
        }
    }

    /// List all performers
    pub fn list(&self) -> Vec<Performer> {
        self.performers
            .iter()
            .map(|p| (*p.value()).clone())
            .collect()
    }
}

impl Default for AgentPool {
    fn default() -> Self {
        Self::new(AgentPoolConfig::default())
    }
}

/// Agent pool statistics
#[derive(Debug, Clone)]
pub struct AgentPoolStats {
    pub total: usize,
    pub idle: usize,
    pub busy: usize,
    pub offline: usize,
    pub max_capacity: usize,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn register_and_acquire() {
        let pool = AgentPool::default();

        let performer = Performer::new("Agent-1")
            .with_capabilities(vec!["rust".to_string(), "typescript".to_string()]);

        pool.register(performer).unwrap();

        // Acquire with matching capability
        let acquired = pool.acquire_performer(&["rust".to_string()]);
        assert!(acquired.is_some());
        assert_eq!(acquired.unwrap().name(), "Agent-1");
    }

    #[test]
    fn acquire_requires_capabilities() {
        let pool = AgentPool::default();

        let performer = Performer::new("Agent-1").with_capabilities(vec!["rust".to_string()]);

        pool.register(performer).unwrap();

        // Try to acquire with non-matching capability
        let acquired = pool.acquire_performer(&["python".to_string()]);
        assert!(acquired.is_none());
    }

    #[test]
    fn capacity_limit() {
        let config = AgentPoolConfig {
            max_performers: 2,
            ..Default::default()
        };
        let pool = AgentPool::new(config);

        pool.register(Performer::new("Agent-1")).unwrap();
        pool.register(Performer::new("Agent-2")).unwrap();

        let result = pool.register(Performer::new("Agent-3"));
        assert!(matches!(result, Err(KallaxError::ResourceExhausted { .. })));
    }
}
