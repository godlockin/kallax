//! Worktree manager for Git worktree isolation
//!
//! Manages git worktrees to provide isolated environments for performers.

use kallax_core::{KallaxError, PerformerId, Result};
use parking_lot::RwLock;
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::process::Command;
use tracing::{error, info, warn};

/// Worktree information
#[derive(Debug, Clone)]
pub struct Worktree {
    pub path: PathBuf,
    pub branch: String,
    pub performer_id: PerformerId,
    pub created_at: chrono::DateTime<chrono::Utc>,
}

/// Worktree manager configuration
#[derive(Debug, Clone)]
pub struct WorktreeManagerConfig {
    /// Base directory for worktrees
    pub worktree_base: PathBuf,
    /// Main repository path
    pub repo_path: PathBuf,
    /// Maximum worktrees allowed
    pub max_worktrees: usize,
}

/// Worktree manager
pub struct WorktreeManager {
    config: WorktreeManagerConfig,
    worktrees: RwLock<HashMap<String, Worktree>>,
}

impl WorktreeManager {
    /// Create a new worktree manager
    pub fn new(config: WorktreeManagerConfig) -> Self {
        Self {
            config,
            worktrees: RwLock::new(HashMap::new()),
        }
    }

    /// Create a worktree for a performer
    pub fn create_worktree(
        &self,
        performer_id: &PerformerId,
        branch_name: &str,
        base_ref: Option<&str>,
    ) -> Result<Worktree> {
        // EPIC-087 P1-7: worktree 泄漏治根 — create 前自动 prune stale
        // 原: 仅显式 prune() 调用, 永不触发 → 泄漏
        // 修: 每次 create 前调 self.prune() (best-effort, 失败不阻塞)
        if let Err(e) = self.prune() {
            warn!(error = %e, "auto-prune before create_worktree failed (continuing)");
        }

        let worktrees = self.worktrees.read();

        // Check capacity
        if worktrees.len() >= self.config.max_worktrees {
            return Err(KallaxError::ResourceExhausted {
                resource: "worktrees",
                limit: self.config.max_worktrees as u64,
                requested: 1,
            });
        }

        // Check if performer already has a worktree
        if worktrees.contains_key(performer_id.as_str()) {
            return Err(KallaxError::AlreadyExists {
                entity_type: "worktree",
                entity_id: performer_id.as_str().to_string(),
            });
        }

        drop(worktrees);

        // Construct worktree path
        let worktree_path = self.config.worktree_base.join(performer_id.as_str());

        // Create worktree directory
        std::fs::create_dir_all(&worktree_path).map_err(|e| KallaxError::io(&worktree_path, e))?;

        // Git worktree add command
        let base = base_ref.unwrap_or("HEAD");
        let output = Command::new("git")
            .current_dir(&self.config.repo_path)
            .args([
                "worktree",
                "add",
                "-b",
                branch_name,
                worktree_path
                    .to_str()
                    .ok_or_else(|| KallaxError::internal("Invalid worktree path"))?,
                base,
            ])
            .output()
            .map_err(|e| KallaxError::io(&self.config.repo_path, e))?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(KallaxError::TaskExecution {
                task_id: format!("worktree_create_{}", performer_id),
                reason: format!("git worktree add failed: {}", stderr),
            });
        }

        let worktree = Worktree {
            path: worktree_path,
            branch: branch_name.to_string(),
            performer_id: performer_id.clone(),
            created_at: chrono::Utc::now(),
        };

        self.worktrees
            .write()
            .insert(performer_id.as_str().to_string(), worktree.clone());

        info!(
            performer_id = %performer_id,
            branch = %branch_name,
            path = %worktree.path.display(),
            "Worktree created"
        );

        Ok(worktree)
    }

    /// Remove a worktree
    pub fn remove_worktree(&self, performer_id: &PerformerId) -> Result<()> {
        let worktree = {
            let worktrees = self.worktrees.read();
            worktrees.get(performer_id.as_str()).cloned()
        };

        let worktree =
            worktree.ok_or_else(|| KallaxError::not_found("worktree", performer_id.as_str()))?;

        // Git worktree remove command
        let output = Command::new("git")
            .current_dir(&self.config.repo_path)
            .args([
                "worktree",
                "remove",
                "--force",
                worktree
                    .path
                    .to_str()
                    .ok_or_else(|| KallaxError::internal("Invalid worktree path"))?,
            ])
            .output()
            .map_err(|e| KallaxError::io(&self.config.repo_path, e))?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            warn!(
                performer_id = %performer_id,
                error = %stderr,
                "git worktree remove failed, trying manual cleanup"
            );

            // Manual cleanup
            if worktree.path.exists() {
                std::fs::remove_dir_all(&worktree.path)
                    .map_err(|e| KallaxError::io(&worktree.path, e))?;
            }
        }

        // Delete branch
        let _ = Command::new("git")
            .current_dir(&self.config.repo_path)
            .args(["branch", "-D", &worktree.branch])
            .output();

        self.worktrees.write().remove(performer_id.as_str());

        info!(
            performer_id = %performer_id,
            "Worktree removed"
        );

        Ok(())
    }

    /// Get worktree for a performer
    pub fn get_worktree(&self, performer_id: &PerformerId) -> Option<Worktree> {
        self.worktrees.read().get(performer_id.as_str()).cloned()
    }

    /// List all worktrees
    pub fn list_worktrees(&self) -> Vec<Worktree> {
        self.worktrees.read().values().cloned().collect()
    }

    /// Prune stale worktrees
    pub fn prune(&self) -> Result<usize> {
        let output = Command::new("git")
            .current_dir(&self.config.repo_path)
            .args(["worktree", "prune"])
            .output()
            .map_err(|e| KallaxError::io(&self.config.repo_path, e))?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(KallaxError::TaskExecution {
                task_id: "worktree_prune".to_string(),
                reason: format!("git worktree prune failed: {}", stderr),
            });
        }

        // Check for stale entries in our tracking
        let mut stale = Vec::new();
        {
            let worktrees = self.worktrees.read();
            for (id, wt) in worktrees.iter() {
                if !wt.path.exists() {
                    stale.push(id.clone());
                }
            }
        }

        let count = stale.len();
        {
            let mut worktrees = self.worktrees.write();
            for id in stale {
                worktrees.remove(&id);
            }
        }

        info!(pruned = count, "Stale worktrees pruned");
        Ok(count)
    }

    /// Verify worktree isolation (no shared paths)
    pub fn verify_isolation(&self) -> Result<()> {
        let worktrees = self.worktrees.read();
        let paths: Vec<_> = worktrees.values().map(|w| &w.path).collect();

        for (i, path_a) in paths.iter().enumerate() {
            for path_b in paths.iter().skip(i + 1) {
                if path_a.starts_with(path_b) || path_b.starts_with(path_a) {
                    return Err(KallaxError::IsolationViolation {
                        performer_id: "system".to_string(),
                        path: path_a.to_path_buf(),
                        scope: vec![path_b.to_path_buf()],
                    });
                }
            }
        }

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    fn setup_test_repo() -> (TempDir, PathBuf) {
        let temp = TempDir::new().unwrap();
        let repo_path = temp.path().to_path_buf();

        // Initialize git repo
        Command::new("git")
            .current_dir(&repo_path)
            .args(["init"])
            .output()
            .unwrap();

        // Create initial commit
        Command::new("git")
            .current_dir(&repo_path)
            .args(["commit", "--allow-empty", "-m", "Initial commit"])
            .output()
            .unwrap();

        (temp, repo_path)
    }

    #[test]
    fn capacity_check() {
        let (_temp, repo_path) = setup_test_repo();
        let worktree_base = repo_path.join(".worktrees");

        let config = WorktreeManagerConfig {
            worktree_base,
            repo_path,
            max_worktrees: 1,
        };

        let manager = WorktreeManager::new(config);

        // Manually add a worktree entry to test capacity
        {
            let mut worktrees = manager.worktrees.write();
            worktrees.insert(
                "existing".to_string(),
                Worktree {
                    // EPIC-101: 用 /tmp 真实存在的 path, 避免被 EPIC-087 prune() 当 stale 删除
                    path: PathBuf::from("/tmp"),
                    branch: "test".to_string(),
                    performer_id: PerformerId::from_str("existing"),
                    created_at: chrono::Utc::now(),
                },
            );
        }

        let result = manager.create_worktree(&PerformerId::from_str("new"), "branch-new", None);

        assert!(matches!(result, Err(KallaxError::ResourceExhausted { .. })));
    }
}
