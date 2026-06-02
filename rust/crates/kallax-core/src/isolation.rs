//! Isolation scope for file-level access control
//!
//! Ensures performers only access files within their designated scope.

use std::path::{Path, PathBuf};
use std::collections::HashSet;

use crate::{KallaxError, Result, PerformerId};

/// Isolation scope defines what files a performer can access
#[derive(Debug, Clone)]
pub struct IsolationScope {
    performer_id: PerformerId,
    allowed_paths: Vec<PathBuf>,
    denied_patterns: Vec<String>,
}

impl IsolationScope {
    /// Create a new isolation scope for a performer
    pub fn new(performer_id: PerformerId) -> Self {
        Self {
            performer_id,
            allowed_paths: Vec::new(),
            denied_patterns: Vec::new(),
        }
    }

    /// Add an allowed path
    pub fn allow_path(mut self, path: impl Into<PathBuf>) -> Self {
        self.allowed_paths.push(path.into());
        self
    }

    /// Add multiple allowed paths
    pub fn allow_paths(mut self, paths: impl IntoIterator<Item = PathBuf>) -> Self {
        self.allowed_paths.extend(paths);
        self
    }

    /// Add a denied pattern (glob-like)
    pub fn deny_pattern(mut self, pattern: impl Into<String>) -> Self {
        self.denied_patterns.push(pattern.into());
        self
    }

    /// Check if a path is within scope
    pub fn is_allowed(&self, path: &Path) -> bool {
        // Check denied patterns first
        let path_str = path.to_string_lossy();
        for pattern in &self.denied_patterns {
            if path_str.contains(pattern) {
                return false;
            }
        }

        // If no allowed paths specified, deny all
        if self.allowed_paths.is_empty() {
            return false;
        }

        // Check if path is under any allowed path
        for allowed in &self.allowed_paths {
            if path.starts_with(allowed) || allowed.starts_with(path) {
                return true;
            }
        }

        false
    }

    /// Validate access to a path, returning error if denied
    pub fn validate_access(&self, path: &Path) -> Result<()> {
        if self.is_allowed(path) {
            Ok(())
        } else {
            Err(KallaxError::IsolationViolation {
                performer_id: self.performer_id.as_str().to_string(),
                path: path.to_path_buf(),
                scope: self.allowed_paths.clone(),
            })
        }
    }

    /// Get allowed paths
    pub fn allowed_paths(&self) -> &[PathBuf] {
        &self.allowed_paths
    }

    /// Get performer ID
    pub fn performer_id(&self) -> &PerformerId {
        &self.performer_id
    }
}

/// Manager for checking scope overlaps between performers
pub struct IsolationManager {
    scopes: Vec<IsolationScope>,
}

impl IsolationManager {
    pub fn new() -> Self {
        Self {
            scopes: Vec::new(),
        }
    }

    /// Add a scope (validates no overlap first)
    pub fn add_scope(&mut self, scope: IsolationScope) -> Result<()> {
        // Check for overlaps with existing scopes
        for existing in &self.scopes {
            if let Some(overlap) = self.find_overlap(existing, &scope) {
                return Err(KallaxError::ScopeOverlap {
                    performer_a: existing.performer_id.as_str().to_string(),
                    performer_b: scope.performer_id.as_str().to_string(),
                    path: overlap,
                });
            }
        }

        self.scopes.push(scope);
        Ok(())
    }

    /// Remove a scope by performer ID
    pub fn remove_scope(&mut self, performer_id: &PerformerId) {
        self.scopes.retain(|s| s.performer_id.as_str() != performer_id.as_str());
    }

    /// Find overlapping path between two scopes
    fn find_overlap(&self, a: &IsolationScope, b: &IsolationScope) -> Option<PathBuf> {
        for path_a in &a.allowed_paths {
            for path_b in &b.allowed_paths {
                // Check if paths overlap (one is prefix of other or same)
                if path_a.starts_with(path_b) || path_b.starts_with(path_a) {
                    return Some(path_a.clone());
                }
            }
        }
        None
    }

    /// Validate access for a performer
    pub fn validate_access(&self, performer_id: &PerformerId, path: &Path) -> Result<()> {
        for scope in &self.scopes {
            if scope.performer_id.as_str() == performer_id.as_str() {
                return scope.validate_access(path);
            }
        }

        // No scope found for performer - deny by default
        Err(KallaxError::NotFound {
            entity_type: "isolation_scope",
            entity_id: performer_id.as_str().to_string(),
        })
    }

    /// Get all paths that are currently claimed
    pub fn claimed_paths(&self) -> HashSet<PathBuf> {
        self.scopes
            .iter()
            .flat_map(|s| s.allowed_paths.iter().cloned())
            .collect()
    }
}

impl Default for IsolationManager {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn scope_allows_subpaths() {
        let scope = IsolationScope::new(PerformerId::from_str("test"))
            .allow_path(PathBuf::from("/src/module"));

        assert!(scope.is_allowed(Path::new("/src/module/file.rs")));
        assert!(scope.is_allowed(Path::new("/src/module")));
        assert!(!scope.is_allowed(Path::new("/src/other")));
    }

    #[test]
    fn scope_denies_patterns() {
        let scope = IsolationScope::new(PerformerId::from_str("test"))
            .allow_path(PathBuf::from("/src"))
            .deny_pattern(".env");

        assert!(scope.is_allowed(Path::new("/src/module/file.rs")));
        assert!(!scope.is_allowed(Path::new("/src/.env")));
        assert!(!scope.is_allowed(Path::new("/src/.env.local")));
    }

    #[test]
    fn manager_detects_overlap() {
        let mut manager = IsolationManager::new();

        let scope1 = IsolationScope::new(PerformerId::from_str("perf1"))
            .allow_path(PathBuf::from("/src/module"));

        let scope2 = IsolationScope::new(PerformerId::from_str("perf2"))
            .allow_path(PathBuf::from("/src/module/sub")); // Overlaps!

        manager.add_scope(scope1).unwrap();
        let result = manager.add_scope(scope2);

        assert!(matches!(result, Err(KallaxError::ScopeOverlap { .. })));
    }

    #[test]
    fn manager_allows_non_overlapping() {
        let mut manager = IsolationManager::new();

        let scope1 = IsolationScope::new(PerformerId::from_str("perf1"))
            .allow_path(PathBuf::from("/src/module_a"));

        let scope2 = IsolationScope::new(PerformerId::from_str("perf2"))
            .allow_path(PathBuf::from("/src/module_b"));

        manager.add_scope(scope1).unwrap();
        manager.add_scope(scope2).unwrap();

        assert_eq!(manager.claimed_paths().len(), 2);
    }
}
