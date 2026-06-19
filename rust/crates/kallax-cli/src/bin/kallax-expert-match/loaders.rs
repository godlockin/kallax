// 跟 v2.7.4 D4.6 联合, 跟 Rule 8 联合. Split from bin/kallax-expert-match.rs.
// Loaders: parse expert .md files, primary nouns, negative signals, last expert from audit.

use super::paths::init_jieba;
use super::types::{
    AuditEntry, Expert, ExpertMatchError, NegativeSignalEntry, PrimaryNounEntry,
};
use jieba::Jieba;
use std::collections::HashSet;
use std::path::Path;

/// Load all experts from the expert directory.
pub fn load_experts(expert_dir: &Path) -> Result<Vec<Expert>, ExpertMatchError> {
    let mut experts = Vec::new();
    if !expert_dir.exists() {
        return Ok(experts);
    }
    for entry in std::fs::read_dir(expert_dir)? {
        let entry = entry?;
        let path = entry.path();
        if path.extension().and_then(|s| s.to_str()) != Some("md") {
            continue;
        }
        let expert = parse_expert_md(&path)?;
        if let Some(e) = expert {
            experts.push(e);
        }
    }
    Ok(experts)
}

/// Parse a single expert .md file.
pub fn parse_expert_md(path: &Path) -> Result<Option<Expert>, ExpertMatchError> {
    let content = std::fs::read_to_string(path)?;
    let mut id = String::new();
    let mut display_name = String::new();
    let mut role = String::new();
    let mut scope = Vec::new();
    let mut primary_nouns = Vec::new();
    let mut triggers = Vec::new();
    let mut negative_signals = Vec::new();
    let mut l2_fallback = None;

    let mut in_section = "";
    for line in content.lines() {
        let line = line.trim();
        if line.starts_with("# ") {
            // Heading: "# Expert: backend"
            let heading = line.trim_start_matches("# ").trim();
            if let Some(rest) = heading.strip_prefix("Expert:") {
                let name = rest.trim();
                id = name.to_lowercase().replace(' ', "-");
                display_name = name.to_string();
            } else if heading.starts_with("Role:") {
                role = heading.trim_start_matches("Role:").trim().to_string();
            }
        } else if line.starts_with("## ") {
            let section = line.trim_start_matches("## ").trim().to_lowercase();
            in_section = match section.as_str() {
                "scope" => "scope",
                "primary nouns" => "primary_nouns",
                "triggers" => "triggers",
                "negative signals" => "negative_signals",
                "l2 fallback" => "l2_fallback",
                _ => "",
            };
        } else if !line.is_empty() && !line.starts_with("#") {
            match in_section {
                "scope" => scope.push(line.to_string()),
                "primary_nouns" => primary_nouns.push(line.to_string()),
                "triggers" => triggers.push(line.to_string()),
                "negative_signals" => negative_signals.push(line.to_string()),
                "l2_fallback" if l2_fallback.is_none() => {
                    l2_fallback = Some(line.to_string());
                }
                _ => {}
            }
        }
    }

    if id.is_empty() {
        return Ok(None);
    }
    Ok(Some(Expert {
        id,
        display_name,
        role,
        scope,
        file: path.to_path_buf(),
        primary_nouns,
        triggers,
        negative_signals,
        l2_fallback,
    }))
}

/// Load PRIMARY_NOUNS.jsonl (跟 v2.7.0 fix 累计 联合).
pub fn load_primary_nouns(path: &Path) -> Result<Vec<PrimaryNounEntry>, ExpertMatchError> {
    let mut entries = Vec::new();
    if !path.exists() {
        return Ok(entries);
    }
    let content = std::fs::read_to_string(path)?;
    for line in content.lines() {
        let line = line.trim();
        if line.is_empty() {
            continue;
        }
        let entry: PrimaryNounEntry = serde_json::from_str(line)
            .map_err(|e| ExpertMatchError::Parse(format!("primary_nouns: {}", e)))?;
        entries.push(entry);
    }
    Ok(entries)
}

/// Load NEGATIVE_SIGNALS.jsonl (跟 v2.7.0 fix 累计 联合).
pub fn load_negative_signals(path: &Path) -> Result<Vec<NegativeSignalEntry>, ExpertMatchError> {
    let mut entries = Vec::new();
    if !path.exists() {
        return Ok(entries);
    }
    let content = std::fs::read_to_string(path)?;
    for line in content.lines() {
        let line = line.trim();
        if line.is_empty() {
            continue;
        }
        let entry: NegativeSignalEntry = serde_json::from_str(line)
            .map_err(|e| ExpertMatchError::Parse(format!("negative_signals: {}", e)))?;
        entries.push(entry);
    }
    Ok(entries)
}

/// Load the most recent expert ID from the audit log (used for session-history rule).
pub fn load_last_expert(audit_log: &Path) -> Option<String> {
    let content = std::fs::read_to_string(audit_log).ok()?;
    let last = content.lines().filter(|l| !l.trim().is_empty()).last_back()?;
    let entry: AuditEntry = serde_json::from_str(last).ok()?;
    Some(entry.id)
}
