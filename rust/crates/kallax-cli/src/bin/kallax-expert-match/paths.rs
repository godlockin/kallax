// 跟 v2.7.4 D4.6 联合, 跟 Rule 8 联合. Split from bin/kallax-expert-match.rs.
// Path resolution: finds KALLAX root, expert dir, primary nouns, negative signals, audit log.

use super::types::ExpertMatchError;
use std::env;
use std::path::PathBuf;

/// Walk up from CWD to find the KALLAX root (directory containing .kallax/).
pub fn resolve_kallax_root() -> PathBuf {
    let mut dir = env::current_dir().unwrap_or_else(|_| PathBuf::from("."));
    loop {
        if dir.join(".kallax").exists() {
            return dir;
        }
        if !dir.pop() {
            // Reached filesystem root; fall back to CWD
            return env::current_dir().unwrap_or_else(|_| PathBuf::from("."));
        }
    }
}

/// Path to the expert definitions directory.
pub fn resolve_expert_dir(kallax_root: &std::path::Path) -> PathBuf {
    kallax_root.join(".kallax/experts/default")
}

/// Path to PRIMARY_NOUNS.jsonl.
pub fn resolve_primary_nouns_path(kallax_root: &std::path::Path) -> PathBuf {
    kallax_root.join(".kallax/experts/PRIMARY_NOUNS.jsonl")
}

/// Path to NEGATIVE_SIGNALS.jsonl.
pub fn resolve_negative_signals_path(kallax_root: &std::path::Path) -> PathBuf {
    kallax_root.join(".kallax/experts/NEGATIVE_SIGNALS.jsonl")
}

/// Path to the audit log (跟 v2.7.0 fix 联合, 跟 .kallax/audit/ 联合).
pub fn resolve_audit_log() -> PathBuf {
    // Prefer XDG-style home, fall back to $HOME, fall back to CWD
    if let Ok(xdg) = env::var("XDG_DATA_HOME") {
        return PathBuf::from(xdg).join("kallax/expert-audit.jsonl");
    }
    if let Ok(home) = env::var("HOME") {
        return PathBuf::from(home).join(".local/share/kallax/expert-audit.jsonl");
    }
    env::current_dir()
        .unwrap_or_else(|_| PathBuf::from("."))
        .join(".kallax/expert-audit.jsonl")
}

pub fn init_jieba() -> Result<jieba::Jieba, ExpertMatchError> {
    jieba::Jieba::new().map_err(|e| ExpertMatchError::JiebaInit(e.to_string()))
}
