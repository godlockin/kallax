// 跟 v2.7.4 D4.6 联合, 跟 Rule 8 联合. Split from bin/kallax-expert-match.rs.
// Scorer: L1a token matching + 4 rules + L2 fallback.

use super::types::{Expert, L2Result, NegativeSignalEntry, PrimaryNounEntry};
use jieba::Jieba;
use std::collections::HashSet;

/// L1a scoring: count token matches against expert triggers + primary nouns.
pub fn score_l1a(tokens: &[String], triggers: &[String], kallax_terms: &[&str]) -> u32 {
    let mut score = 0u32;
    for token in tokens {
        for trigger in triggers {
            if token_match(token, trigger) {
                score += 10;
            }
        }
        for term in kallax_terms {
            if token.eq_ignore_ascii_case(term) {
                score += 5;
            }
        }
    }
    score
}

/// Check if a token matches a candidate string (substring or fuzzy).
pub fn token_match(token: &str, candidate: &str) -> bool {
    let token_lower = token.to_lowercase();
    let candidate_lower = candidate.to_lowercase();
    token_lower == candidate_lower
        || token_lower.contains(&candidate_lower)
        || candidate_lower.contains(&token_lower)
}

/// Rule 1: Primary noun match (highest weight).
pub fn apply_rule1_primary_nouns(
    tokens: &[String],
    experts: &mut [(Expert, u32)],
    primary_nouns: &[PrimaryNounEntry],
) -> bool {
    let mut matched = false;
    let mut token_to_expert: HashSet<(usize, String)> = HashSet::new();
    for (ei, (expert, score)) in experts.iter_mut().enumerate() {
        for noun in &expert.primary_nouns {
            for (ti, token) in tokens.iter().enumerate() {
                if token_match(token, noun) {
                    *score += 25;
                    token_to_expert.insert((ti, expert.id.clone()));
                    matched = true;
                }
            }
        }
        // Boost for PRIMARY_NOUNS.jsonl match
        for entry in primary_nouns {
            if entry.expert_id == expert.id {
                for (ti, token) in tokens.iter().enumerate() {
                    if token_match(token, &entry.noun) {
                        *score += 15;
                        matched = true;
                    }
                }
            }
        }
    }
    matched
}

/// Rule 2: Negative signal veto (block if matched).
pub fn apply_rule2_negative_signals(
    tokens: &[String],
    experts: &mut [(Expert, u32)],
    negative_signals: &[NegativeSignalEntry],
) -> bool {
    let mut vetoed = false;
    for (expert, score) in experts.iter_mut() {
        for entry in negative_signals {
            if entry.expert_id == expert.id {
                for token in tokens {
                    if token_match(token, &entry.signal) {
                        *score = score.saturating_sub(50);
                        vetoed = true;
                    }
                }
            }
        }
    }
    vetoed
}

/// Rule 3: Session history boost (boost the last used expert).
pub fn apply_rule3_session_history(
    experts: &mut [(Expert, u32)],
    last_expert: Option<&str>,
) -> bool {
    let mut applied = false;
    if let Some(last_id) = last_expert {
        for (expert, score) in experts.iter_mut() {
            if expert.id == last_id {
                *score += 20;
                applied = true;
            }
        }
    }
    applied
}

/// Rule 4: Tiebreaker (sort by score, then by id alphabetically).
pub fn apply_rule4_tiebreaker(candidates: &mut Vec<(String, u32)>) -> bool {
    candidates.sort_by(|a, b| b.1.cmp(&a.1).then_with(|| a.0.cmp(&b.0)));
    true
}

/// L2 fallback: if L1a scores are all low, try semantic / keyword fallback.
pub fn apply_l2_fallback(
    tokens: &[String],
    experts: &[Expert],
    jieba: &Jieba,
) -> Option<L2Result> {
    let mut best: Option<L2Result> = None;
    for expert in experts {
        let score = score_l1a(tokens, &expert.triggers, &[]);
        if best.as_ref().map_or(true, |b| score > b.score) {
            best = Some(L2Result {
                best_expert: expert.id.clone(),
                score,
                reason: format!("L2 fallback: keyword match (triggers={})", expert.triggers.len()),
            });
        }
    }
    let _ = jieba; // reserved for future semantic scoring
    best
}
