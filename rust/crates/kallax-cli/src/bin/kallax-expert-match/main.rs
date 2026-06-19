// 跟 v2.7.4 D4.6 联合, 跟 Rule 8 联合. Split from bin/kallax-expert-match.rs.
// Main entry point: ties loaders, scorer, and audit together for the CLI.

mod audit;
mod loaders;
mod paths;
mod scorer;
mod types;

use audit::{format_human, write_audit_log};
use loaders::{load_experts, load_last_expert, load_negative_signals, load_primary_nouns, parse_expert_md};
use paths::{
    init_jieba, resolve_audit_log, resolve_expert_dir, resolve_kallax_root,
    resolve_negative_signals_path, resolve_primary_nouns_path,
};
use scorer::{apply_l2_fallback, apply_rule1_primary_nouns, apply_rule2_negative_signals, apply_rule3_session_history, apply_rule4_tiebreaker, score_l1a, token_match};
use types::{AuditEntry, Expert, ExpertMatchError, MatchResult, NegativeSignalEntry, PrimaryNounEntry};
use std::collections::HashSet;
use std::path::Path;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = std::env::args().collect();
    let json_output = args.iter().any(|a| a == "--json");
    let mut requirement = String::new();
    for arg in args.iter().skip(1) {
        if !arg.starts_with("--") && requirement.is_empty() {
            requirement = arg.clone();
        }
    }
    if requirement.is_empty() {
        eprintln!("Usage: kallax-expert-match <requirement> [--json]");
        std::process::exit(2);
    }

    let start = std::time::Instant::now();
    let kallax_root = resolve_kallax_root();
    let expert_dir = resolve_expert_dir(&kallax_root);
    let primary_nouns_path = resolve_primary_nouns_path(&kallax_root);
    let negative_signals_path = resolve_negative_signals_path(&kallax_root);
    let audit_log_path = resolve_audit_log();

    let jieba = init_jieba()?;
    let experts = load_experts(&expert_dir)?;
    let primary_nouns = load_primary_nouns(&primary_nouns_path)?;
    let negative_signals = load_negative_signals(&negative_signals_path)?;
    let last_expert = load_last_expert(&audit_log_path);

    // Tokenize the requirement using jieba
    let tokens: Vec<String> = jieba
        .cut_all(&requirement)
        .into_iter()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty() && s.len() > 1)
        .collect();

    // Initialize scores
    let mut scored: Vec<(Expert, u32)> = experts
        .iter()
        .map(|e| (e.clone(), score_l1a(&tokens, &e.triggers, &["kallax", "expert", "conductor", "performer"])))
        .collect();

    // Apply 4 rules
    let r1 = apply_rule1_primary_nouns(&tokens, &mut scored, &primary_nouns);
    let r2 = apply_rule2_negative_signals(&tokens, &mut scored, &negative_signals);
    let r3 = apply_rule3_session_history(&mut scored, last_expert.as_deref());

    // Build candidates for tiebreaking
    let mut candidates: Vec<(String, u32)> = scored.iter().map(|(e, s)| (e.id.clone(), *s)).collect();
    apply_rule4_tiebreaker(&mut candidates);

    // Pick best
    let (best_id, best_score) = candidates.first().cloned().unwrap_or_else(|| ("unknown".to_string(), 0));
    let best_expert = scored.iter().find(|(e, _)| e.id == best_id).cloned();

    // L2 fallback if all scores are low
    let ambiguous = scored.iter().filter(|(_, s)| *s >= best_score.saturating_sub(10)).count() > 1;
    let (via, reason) = if best_score < 20 {
        if let Some(l2) = apply_l2_fallback(&tokens, &experts, &jieba) {
            ("L2", l2.reason)
        } else {
            ("L1a", "L1a score below threshold (20), no L2 fallback".to_string())
        }
    } else if r1 {
        ("L1+Rule1", "Primary noun match".to_string())
    } else if r2 {
        ("L1+Rule2", "Negative signal veto".to_string())
    } else if r3 {
        ("L1+Rule3", "Session history".to_string())
    } else {
        ("L1a", format!("L1a score={}", best_score))
    };

    let confidence = match best_score {
        0..=20 => "low",
        21..=50 => "medium",
        _ => "high",
    };

    let duration_ms = start.elapsed().as_millis() as u64;

    let result = MatchResult {
        via: via.to_string(),
        best_expert: best_id.clone(),
        score: best_score,
        confidence: confidence.to_string(),
        duration_ms,
        reason: reason.clone(),
    };

    // Write audit log
    let audit_entry = AuditEntry {
        ts: chrono::Utc::now().format("%Y-%m-%dT%H:%M:%SZ").to_string(),
        req: requirement.clone(),
        via: via.to_string(),
        id: best_id,
        score: best_score,
        ambiguous,
        reason,
        duration_ms,
    };

    if let Err(e) = write_audit_log(&audit_log_path, &audit_entry) {
        eprintln!("Warning: Failed to write audit log: {}", e);
    }

    // Output
    if json_output {
        println!("{}", serde_json::to_string_pretty(&result)?);
    } else {
        println!("{}", format_human(&result));
    }

    Ok(())
}
