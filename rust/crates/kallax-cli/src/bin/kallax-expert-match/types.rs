// 跟 v2.7.4 D4.6 联合, 跟 Rule 8 联合. Split from bin/kallax-expert-match.rs.
// 跟 CLEANUP-PHILOSOPHY.md 5 原则 联合, 跟 v2.7.4 check-anti-patterns.sh 7 anti-pattern 联合.

use chrono::{DateTime, Utc};
use jieba::Jieba;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::{Path, PathBuf};

// ---------------------------------------------------------------------------
// Expert: parsed from .md expert file
// ---------------------------------------------------------------------------

/// An expert profile parsed from a .md file under `.kallax/experts/default/`.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Expert {
    pub id: String,
    pub display_name: String,
    pub role: String,
    pub scope: Vec<String>,
    pub file: PathBuf,
    pub primary_nouns: Vec<String>,
    pub triggers: Vec<String>,
    pub negative_signals: Vec<String>,
    pub l2_fallback: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PrimaryNounEntry {
    pub noun: String,
    pub expert_id: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NegativeSignalEntry {
    pub signal: String,
    pub expert_id: String,
    pub reason: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuditEntry {
    pub ts: String,
    pub req: String,
    pub via: String,
    pub id: String,
    pub score: u32,
    pub ambiguous: bool,
    pub reason: String,
    pub duration_ms: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MatchResult {
    pub via: String,
    pub best_expert: String,
    pub score: u32,
    pub confidence: String,
    pub duration_ms: u64,
    pub reason: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct L2Result {
    pub best_expert: String,
    pub score: u32,
    pub reason: String,
}

// ---------------------------------------------------------------------------
// ExpertMatchError
// ---------------------------------------------------------------------------

#[derive(Debug)]
pub enum ExpertMatchError {
    Io(std::io::Error),
    Parse(String),
    Serde(String),
    JiebaInit(String),
}

impl std::fmt::Display for ExpertMatchError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Io(e) => write!(f, "I/O error: {}", e),
            Self::Parse(s) => write!(f, "parse error: {}", s),
            Self::Serde(s) => write!(f, "serde error: {}", s),
            Self::JiebaInit(s) => write!(f, "jieba init error: {}", s),
        }
    }
}

impl std::error::Error for ExpertMatchError {}

impl From<std::io::Error> for ExpertMatchError {
    fn from(e: std::io::Error) -> Self { Self::Io(e) }
}

impl From<serde_json::Error> for ExpertMatchError {
    fn from(e: serde_json::Error) -> Self { Self::Serde(e.to_string()) }
}
