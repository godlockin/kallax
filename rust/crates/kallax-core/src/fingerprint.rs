//! Content fingerprinting for KALLAX file change detection
//!
//! Computes SHA256 file hashes and compares fingerprint snapshots
//! to detect added, modified, or removed files — enabling efficient
//! incrementality analysis for isolation scopes and worktree state.

use chrono::{DateTime, Utc};
use dashmap::DashMap;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::HashSet;
use std::io::Read;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::SystemTime;

use crate::{KallaxError, Result};

// ─────────────────────────────────────────────────────────────────────────────
// Data types
// ─────────────────────────────────────────────────────────────────────────────

/// Type of change detected when diffing fingerprint snapshots
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ChangeType {
    Added,
    Modified,
    Removed,
}

/// A single file change detected during fingerprint comparison
#[derive(Debug, Clone)]
pub struct Change {
    pub path: PathBuf,
    pub change_type: ChangeType,
}

/// SHA256 fingerprint of a file's content at a point in time
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ContentFingerprint {
    pub path: PathBuf,
    pub sha256_hash: String,
    pub modified_at: DateTime<Utc>,
}

// ─────────────────────────────────────────────────────────────────────────────
// FingerprintStore trait
// ─────────────────────────────────────────────────────────────────────────────

/// Storage and comparison for content fingerprints.
///
/// Implementations must be `Send + Sync` for use in concurrent contexts.
#[async_trait::async_trait]
pub trait FingerprintStore: Send + Sync {
    /// Persist a fingerprint
    async fn save(&self, fingerprint: &ContentFingerprint) -> Result<()>;

    /// Load the fingerprint for a path, or NotFound error
    async fn load(&self, path: &Path) -> Result<ContentFingerprint>;

    /// Compare new fingerprints against stored state, returning all changes.
    ///
    /// The caller supplies the current set of fingerprints (e.g. computed by
    /// scanning a directory). The store compares these against its previous
    /// snapshot and returns Added / Modified / Removed entries.
    async fn diff(&self, new_fingerprints: &[ContentFingerprint]) -> Result<Vec<Change>>;
}

// ─────────────────────────────────────────────────────────────────────────────
// compute_fingerprint
// ─────────────────────────────────────────────────────────────────────────────

/// Compute the SHA256 fingerprint of a file at the given path.
///
/// Reads the file in 8 KiB chunks to avoid loading large files entirely
/// into memory. Returns the hash as a 64-character hex string along with
/// the file's modification timestamp.
pub fn compute_fingerprint(path: impl Into<PathBuf>) -> Result<ContentFingerprint> {
    let path = path.into();

    let metadata = std::fs::metadata(&path).map_err(|e| KallaxError::io(&path, e))?;

    if !metadata.is_file() {
        return Err(KallaxError::validation(
            "path",
            format!("not a regular file: {}", path.display()),
        ));
    }

    let mut file = std::fs::File::open(&path).map_err(|e| KallaxError::io(&path, e))?;

    let mut hasher = Sha256::new();
    let mut buffer = [0u8; 8192];
    loop {
        let n = file.read(&mut buffer).map_err(|e| KallaxError::io(&path, e))?;
        if n == 0 {
            break;
        }
        hasher.update(&buffer[..n]);
    }

    let sha256_hash = format!("{:x}", hasher.finalize());

    let modified_at = metadata
        .modified()
        .map_err(|e| KallaxError::io(&path, e))?;

    let duration = modified_at
        .duration_since(SystemTime::UNIX_EPOCH)
        .map_err(|e| KallaxError::io(&path, e))?;

    let modified_at =
        DateTime::from_timestamp(duration.as_secs() as i64, duration.subsec_nanos())
            .ok_or_else(|| {
                KallaxError::io(&path, "system time is before unix epoch")
            })?;

    Ok(ContentFingerprint {
        path,
        sha256_hash,
        modified_at,
    })
}

// ─────────────────────────────────────────────────────────────────────────────
// MemoryStore
// ─────────────────────────────────────────────────────────────────────────────

/// In-memory fingerprint store backed by DashMap.
///
/// Thread-safe, lock-free reads. Suitable for single-process use cases
/// such as worktree state tracking and test fixtures.
pub struct MemoryStore {
    store: Arc<DashMap<PathBuf, ContentFingerprint>>,
}

impl MemoryStore {
    pub fn new() -> Self {
        Self {
            store: Arc::new(DashMap::new()),
        }
    }
}

impl Default for MemoryStore {
    fn default() -> Self {
        Self::new()
    }
}

#[async_trait::async_trait]
impl FingerprintStore for MemoryStore {
    async fn save(&self, fingerprint: &ContentFingerprint) -> Result<()> {
        self.store
            .insert(fingerprint.path.clone(), fingerprint.clone());
        Ok(())
    }

    async fn load(&self, path: &Path) -> Result<ContentFingerprint> {
        self.store
            .get(path)
            .map(|r| r.value().clone())
            .ok_or_else(|| KallaxError::not_found("fingerprint", path.display().to_string()))
    }

    async fn diff(&self, new_fingerprints: &[ContentFingerprint]) -> Result<Vec<Change>> {
        let mut changes = Vec::new();
        let new_paths: HashSet<PathBuf> =
            new_fingerprints.iter().map(|f| f.path.clone()).collect();

        // Detect added or modified files
        for fp in new_fingerprints {
            match self.store.get(&fp.path) {
                None => {
                    changes.push(Change {
                        path: fp.path.clone(),
                        change_type: ChangeType::Added,
                    });
                }
                Some(existing) if existing.sha256_hash != fp.sha256_hash => {
                    changes.push(Change {
                        path: fp.path.clone(),
                        change_type: ChangeType::Modified,
                    });
                }
                Some(_) => {
                    // Unchanged — skip
                }
            }
        }

        // Detect removed files
        for entry in self.store.iter() {
            if !new_paths.contains(entry.key()) {
                changes.push(Change {
                    path: entry.key().clone(),
                    change_type: ChangeType::Removed,
                });
            }
        }

        Ok(changes)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::io::Write;

    #[test]
    fn compute_fingerprint_for_file() {
        let dir = std::env::temp_dir().join(format!("kallax-fp-{}", uuid::Uuid::new_v4()));
        fs::create_dir_all(&dir).expect("create temp dir");
        let file_path = dir.join("test.txt");
        let mut f = fs::File::create(&file_path).expect("create test file");
        f.write_all(b"hello world").expect("write content");

        let fp = compute_fingerprint(&file_path).expect("should compute fingerprint");
        assert_eq!(fp.path, file_path);
        // SHA256("hello world") without trailing newline
        assert_eq!(
            fp.sha256_hash,
            "b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9"
        );

        fs::remove_dir_all(dir).expect("cleanup temp dir");
    }

    #[test]
    fn compute_fingerprint_nonexistent_file_returns_error() {
        let result = compute_fingerprint("/tmp/kallax-nonexistent-test-file-12345.txt");
        assert!(result.is_err());
    }

    #[test]
    fn compute_fingerprint_on_directory_returns_validation_error() {
        let result = compute_fingerprint("/tmp");
        assert!(result.is_err());
        assert!(matches!(result.unwrap_err(), KallaxError::Validation { .. }));
    }

    #[test]
    fn compute_fingerprint_sha256_is_64_hex_chars() {
        let dir = std::env::temp_dir().join(format!("kallax-fp2-{}", uuid::Uuid::new_v4()));
        fs::create_dir_all(&dir).expect("create temp dir");
        let file_path = dir.join("a.txt");
        fs::write(&file_path, b"some content").expect("write");
        let fp = compute_fingerprint(&file_path).expect("compute");
        assert_eq!(fp.sha256_hash.len(), 64);
        assert!(fp.sha256_hash.chars().all(|c| c.is_ascii_hexdigit()));
        fs::remove_dir_all(dir).expect("cleanup");
    }

    #[tokio::test]
    async fn memory_store_save_and_load() {
        let store = MemoryStore::new();
        let path = PathBuf::from("/test/file.rs");
        let fp = ContentFingerprint {
            path: path.clone(),
            sha256_hash: "abc123".to_string(),
            modified_at: Utc::now(),
        };

        store.save(&fp).await.expect("save should succeed");
        let loaded = store.load(&path).await.expect("load should succeed");
        assert_eq!(loaded.sha256_hash, "abc123");
    }

    #[tokio::test]
    async fn memory_store_load_nonexistent_returns_error() {
        let store = MemoryStore::new();
        let result = store.load(Path::new("/no/such/file")).await;
        assert!(result.is_err());
        assert!(matches!(result.unwrap_err(), KallaxError::NotFound { .. }));
    }

    #[tokio::test]
    async fn memory_store_diff_detects_additions() {
        let store = MemoryStore::new();
        let fp = ContentFingerprint {
            path: PathBuf::from("/new/file.rs"),
            sha256_hash: "hash1".to_string(),
            modified_at: Utc::now(),
        };

        let changes = store.diff(&[fp]).await.expect("diff should succeed");
        assert_eq!(changes.len(), 1);
        assert_eq!(changes[0].change_type, ChangeType::Added);
    }

    #[tokio::test]
    async fn memory_store_diff_detects_removals() {
        let store = MemoryStore::new();
        let path = PathBuf::from("/old/file.rs");
        let fp = ContentFingerprint {
            path: path.clone(),
            sha256_hash: "hash1".to_string(),
            modified_at: Utc::now(),
        };
        store.save(&fp).await.unwrap();

        let changes = store.diff(&[]).await.expect("diff should succeed");
        assert_eq!(changes.len(), 1);
        assert_eq!(changes[0].change_type, ChangeType::Removed);
    }

    #[tokio::test]
    async fn memory_store_diff_detects_modifications() {
        let store = MemoryStore::new();
        let path = PathBuf::from("/file.rs");
        let old = ContentFingerprint {
            path: path.clone(),
            sha256_hash: "old_hash".to_string(),
            modified_at: Utc::now(),
        };
        store.save(&old).await.unwrap();

        let new = ContentFingerprint {
            path,
            sha256_hash: "new_hash".to_string(),
            modified_at: Utc::now(),
        };

        let changes = store.diff(&[new]).await.expect("diff should succeed");
        assert_eq!(changes.len(), 1);
        assert_eq!(changes[0].change_type, ChangeType::Modified);
    }

    #[tokio::test]
    async fn memory_store_diff_unchanged_files_are_skipped() {
        let store = MemoryStore::new();
        let path = PathBuf::from("/file.rs");
        let fp = ContentFingerprint {
            path: path.clone(),
            sha256_hash: "same_hash".to_string(),
            modified_at: Utc::now(),
        };
        store.save(&fp).await.unwrap();

        let changes = store.diff(&[fp]).await.expect("diff should succeed");
        assert_eq!(changes.len(), 0, "unchanged files should not appear in diff");
    }

    #[tokio::test]
    async fn memory_store_diff_handles_add_remove_modify_combination() {
        let store = MemoryStore::new();

        // Seed store with two files
        let a = ContentFingerprint {
            path: PathBuf::from("/a.rs"),
            sha256_hash: "hash_a".to_string(),
            modified_at: Utc::now(),
        };
        let b = ContentFingerprint {
            path: PathBuf::from("/b.rs"),
            sha256_hash: "hash_b".to_string(),
            modified_at: Utc::now(),
        };
        store.save(&a).await.unwrap();
        store.save(&b).await.unwrap();

        // New snapshot: b modified, c added, a removed
        let b_modified = ContentFingerprint {
            path: PathBuf::from("/b.rs"),
            sha256_hash: "hash_b_new".to_string(),
            modified_at: Utc::now(),
        };
        let c = ContentFingerprint {
            path: PathBuf::from("/c.rs"),
            sha256_hash: "hash_c".to_string(),
            modified_at: Utc::now(),
        };

        let changes = store.diff(&[b_modified, c]).await.expect("diff should succeed");
        assert_eq!(changes.len(), 3);

        let types: Vec<ChangeType> = changes.iter().map(|c| c.change_type.clone()).collect();
        assert!(types.contains(&ChangeType::Added));
        assert!(types.contains(&ChangeType::Modified));
        assert!(types.contains(&ChangeType::Removed));
    }
}
