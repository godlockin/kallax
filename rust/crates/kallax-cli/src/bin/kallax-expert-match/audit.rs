// 跟 v2.7.4 D4.6 联合, 跟 Rule 8 联合. Split from bin/kallax-expert-match.rs.
// Audit: write audit log + human format helpers.

use super::types::{AuditEntry, MatchResult};
use std::path::Path;

/// Append an entry to the audit log.
pub fn write_audit_log(audit_log: &Path, entry: &AuditEntry) -> Result<(), std::io::Error> {
    if let Some(parent) = audit_log.parent() {
        std::fs::create_dir_all(parent)?;
    }
    use std::io::Write;
    let mut file = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(audit_log)?;
    writeln!(file, "{}", serde_json::to_string(entry).unwrap_or_default())?;
    Ok(())
}

/// Format a MatchResult as human-readable text.
pub fn format_human(result: &MatchResult) -> String {
    format!(
        "Best expert: {} (score: {}, confidence: {})\nVia: {}\nDuration: {}ms\nReason: {}",
        result.best_expert, result.score, result.confidence, result.via, result.duration_ms, result.reason,
    )
}
