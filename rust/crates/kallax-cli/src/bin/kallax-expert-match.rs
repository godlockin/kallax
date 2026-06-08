//! kallax-expert-match — L1 Expert Matching Binary for KALLAX
//!
//! Rust reimplementation of expert-match.sh solving:
//! - Chinese tokenization (jieba-rs)
//! - Performance (pure Rust, no subprocess calls)
//! - L1b integration (4 rules)
//!
//! Usage:
//!   kallax-expert-match "页面加载慢"
//!   kallax-expert-match "用户跳出" --json
//!   kallax-expert-match --help

use jieba_rs::Jieba;
use regex::Regex;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs::{self, File};
use std::io::{BufRead, BufReader, Write};
use std::path::{Path, PathBuf};
use std::time::Instant;

// ============================================================================
// Types
// ============================================================================

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Expert {
    pub id: String,
    pub name: String,
    #[serde(default)]
    pub domain: String,
    pub trigger: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PrimaryNounEntry {
    pub expert_id: String,
    pub nouns: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NegativeSignalEntry {
    pub triggers: Vec<String>,
    pub exclude_experts: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuditEntry {
    pub ts: String,
    pub req: String,
    #[serde(rename = "via")]
    pub via: String,
    pub id: String,
    pub score: u32,
    #[serde(default)]
    pub ambiguous: bool,
    #[serde(default)]
    pub reason: String,
    #[serde(rename = "duration_ms")]
    pub duration_ms: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MatchResult {
    #[serde(rename = "via")]
    pub via: String,
    #[serde(rename = "best_expert")]
    pub best_expert: String,
    pub score: u32,
    pub confidence: String,
    #[serde(rename = "duration_ms")]
    pub duration_ms: u64,
    pub reason: String,
}

// ============================================================================
// KALLAX Domain Dictionary — extracted from 7 expert trigger fields + UX/PM
// ============================================================================

const KALLAX_TERMS: &[&str] = &[
    // architect (from trigger + manual + expanded)
    "微服务", "服务拆分", "模块边界", "解耦", "依赖管理", "循环依赖",
    "接口对不上", "跨服务调用", "分布式", "系统设计", "架构", "重构",
    "抽象层", "技术选型", "模块耦合", "接口契约", "API定义", "链路追踪",
    "灰度发布", "灰度", "SLA", "SLO", "容量规划", "服务网格", "Sidecar",
    "容器化", "K8s", "Kubernetes", "弹性伸缩", "熔断", "限流", "降级",
    "读写分离", "分库分表", "CQRS", "事件溯源", " Saga模式",
    // backend (from trigger + manual + expanded)
    "接口慢", "数据库索引", "请求超时", "5xx", "504", "502", "503",
    "缓存击穿", "死锁", "deadlock", "锁", "锁竞争", "连接耗尽", "GC",
    "OOM", "内存泄漏", "慢SQL", "N+1", "连接池", "服务端", "后端报错",
    "API", "接口", "SQL", "查询", "事务", "缓存", "性能", "后端",
    "数据层", "慢查询", "数据库", "查询慢", "数据库崩溃", "数据库连接",
    "主从复制", "读写分离", "慢查询优化", "SQL注入", "跨库查询",
    "分布式事务", "TCC", "可靠消息", "最终一致性", "压测", "基准测试",
    "连接池配置", "连接泄漏", "半开连接", "重试机制", "幂等性",
    // frontend (from trigger + manual + expanded)
    "页面卡", "白屏", "首屏慢", "样式错乱", "加载慢", "点击没反应",
    "动画卡", "滚动卡", "重渲染", "组件耦合", "状态管理混乱",
    "页面", "组件", "渲染", "React", "Vue", "样式", "DOM", "LCP",
    "首屏", "懒加载", "重渲染", "UI", "FCP", "FID", "CLS", "TTI",
    "闪退", "黑屏", "抖动", "卡帧", "内存溢出", "包体积", "代码分割",
    "TreeShaking", "SSR", "SSG", " hydration", "虚拟列表", "无限滚动",
    "骨架屏", "loading", "spinner", "loading态", "错误边界", "降级UI",
    "可访问性", "a11y", "WCAG", "键盘导航", "屏幕阅读器", "ARIA",
    // ux (from trigger + manual + expanded)
    "用户跳出", "按钮点击率", "学习成本", "新用户不会用", "步骤太多",
    "用户旅程", "界面卡", "操作复杂", "体验", "旅程", "流程", "可用性",
    "认知", "行为", "转化", "跳出", "流失", "留存", "活跃", "转化漏斗",
    "NPS", "用户留存", "日活", "月活", "用户粘性", "跳出率", "转化率",
    "漏斗分析", "用户路径", "行为分析", "热力图", "点击图", "滚动深度",
    "A/B测试", "ABtest", "用户研究", "访谈", "问卷", "反馈", "评价",
    // product (from trigger + manual + expanded)
    "要不要做", "砍功能", "MVP", "ROI", "PRD", "优先级排序",
    "需求", "功能", "优先级", "价值", "版本", "规划", "路线图",
    "灰度发布", "A/B测试", "用户故事", "PRD", "MRD", "BRD",
    "路线图", "版本规划", "迭代", " sprint", "backlog", "kanban",
    "需求池", "需求评审", "优先级评估", "价值评估", "工作量评估",
    "技术债", "产品策略", "增长", "留存", "活跃", "变现",
    // security (from trigger + manual + expanded)
    "被攻击", "数据泄露", "越权", "撞库", "XSS", "CSRF", "OWASP",
    "漏洞", "攻击", "注入", "鉴权", "泄露", "合规", "SSRF", "IDOR",
    "提权", "权限提升", "越权访问", "未授权", "认证", "授权", "OAuth",
    "JWT", "Token", "会话管理", "Cookie", "Session", "CSRF", "SQL注入",
    "命令注入", "路径穿越", "文件上传", "下载", "敏感信息", "密码",
    "加密", "解密", "哈希", "签名", "证书", "TLS", "HTTPS", "安全审计",
    "渗透测试", "漏洞扫描", "安全加固", "安全配置", "防火墙", "WAF",
    // pm (from trigger + manual + expanded)
    "跨ticket", "团队任务分配", "延期", "谁负责", "排期", "owner",
    "协调", "任务", "排期", "风险", "跨团队", "对接", "阻塞",
    "资源冲突", "依赖关系", "风险评估", "项目延期", "进度延迟",
    "任务阻塞", " blocker", "critical", "P0", "P1", "hotfix", "紧急修复",
    "发布阻塞", "环境问题", "环境配置", "部署失败", "回滚", "数据迁移",
];

// ============================================================================
// Error Handling
// ============================================================================

#[derive(Debug)]
pub enum ExpertMatchError {
    IoError(std::io::Error),
    ParseError(String),
    JsonError(serde_json::Error),
}

impl std::fmt::Display for ExpertMatchError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ExpertMatchError::IoError(e) => write!(f, "IO error: {}", e),
            ExpertMatchError::ParseError(e) => write!(f, "Parse error: {}", e),
            ExpertMatchError::JsonError(e) => write!(f, "JSON error: {}", e),
        }
    }
}

impl std::error::Error for ExpertMatchError {}

impl From<std::io::Error> for ExpertMatchError {
    fn from(err: std::io::Error) -> Self {
        ExpertMatchError::IoError(err)
    }
}

impl From<serde_json::Error> for ExpertMatchError {
    fn from(err: serde_json::Error) -> Self {
        ExpertMatchError::JsonError(err)
    }
}

// ============================================================================
// Path Resolution
// ============================================================================

fn resolve_kallax_root() -> PathBuf {
    // KALLAX_ROOT env var or default to .kallax in repo root
    std::env::var("KALLAX_ROOT")
        .map(PathBuf::from)
        .unwrap_or_else(|_| {
            let exe = std::env::current_exe().unwrap_or_default();
            // Navigate from target/release/kallax-expert-match to repo root
            let repo = exe.ancestors()
                .nth(4)  // target/release/kallax-expert-match -> repo root
                .unwrap_or_else(|| Path::new("."));
            repo.join(".kallax")
        })
}

fn resolve_expert_dir(kallax_root: &Path) -> PathBuf {
    kallax_root.join("experts").join("default")
}

fn resolve_primary_nouns_path(kallax_root: &Path) -> PathBuf {
    kallax_root.join("experts").join("PRIMARY_NOUNS.md")
}

fn resolve_negative_signals_path(kallax_root: &Path) -> PathBuf {
    kallax_root.join("experts").join("NEGATIVE_SIGNALS.md")
}

fn resolve_audit_log() -> PathBuf {
    dirs::home_dir()
        .unwrap_or_else(|| PathBuf::from("."))
        .join(".kallax")
        .join("logs")
        .join("expert_resolution_audit.jsonl")
}

// ============================================================================
// Jieba Initialization with KALLAX Dictionary
// ============================================================================

fn init_jieba() -> Jieba {
    let mut jieba = Jieba::new();
    for term in KALLAX_TERMS {
        jieba.add_word(term, None, None);
    }
    jieba
}

// ============================================================================
// Expert Loading
// ============================================================================

fn load_experts(expert_dir: &Path) -> Result<Vec<Expert>, ExpertMatchError> {
    let mut experts = Vec::new();

    let entries = fs::read_dir(expert_dir)?;
    for entry in entries {
        let entry = entry?;
        let path = entry.path();
        if path.extension().and_then(|s| s.to_str()) != Some("md") {
            continue;
        }

        let expert = parse_expert_md(&path)?;
        if expert.is_some() {
            experts.push(expert.unwrap());
        }
    }

    Ok(experts)
}

fn parse_expert_md(path: &Path) -> Result<Option<Expert>, ExpertMatchError> {
    let content = fs::read_to_string(path)?;
    let id = path.file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or("unknown")
        .to_string();

    // Parse frontmatter trigger: field
    let mut trigger = Vec::new();
    let mut in_frontmatter = false;
    let mut frontmatter_end = false;

    for line in content.lines() {
        let trimmed = line.trim();

        if trimmed == "---" {
            if !in_frontmatter {
                in_frontmatter = true;
            } else if !frontmatter_end {
                frontmatter_end = true;
                break;
            }
            continue;
        }

        if in_frontmatter && trimmed.starts_with("trigger:") {
            let trigger_line = trimmed.strip_prefix("trigger:").unwrap_or("");
            for item in trigger_line.split(',') {
                let item = item.trim();
                if !item.is_empty() {
                    trigger.push(item.to_string());
                }
            }
        }
    }

    if trigger.is_empty() {
        return Ok(None);
    }

    // Extract name from content if available
    let name = content.lines()
        .find(|l| l.starts_with("name:"))
        .and_then(|l| l.strip_prefix("name:"))
        .map(|s| s.trim().to_string())
        .unwrap_or_else(|| id.clone());

    Ok(Some(Expert {
        id,
        name,
        domain: String::new(),
        trigger,
    }))
}

// ============================================================================
// Primary Nouns Loading
// ============================================================================

fn load_primary_nouns(path: &Path) -> Result<Vec<PrimaryNounEntry>, ExpertMatchError> {
    if !path.exists() {
        return Ok(Vec::new());
    }

    let content = fs::read_to_string(path)?;
    let mut entries = Vec::new();
    let mut current_expert = String::new();
    let mut current_nouns = Vec::new();

    for line in content.lines() {
        let trimmed = line.trim();

        // Skip comments and empty lines
        if trimmed.is_empty() || trimmed.starts_with('#') {
            continue;
        }

        // Parse ## expert_id
        if trimmed.starts_with("## ") {
            // Save previous entry
            if !current_expert.is_empty() && !current_nouns.is_empty() {
                entries.push(PrimaryNounEntry {
                    expert_id: current_expert.clone(),
                    nouns: std::mem::take(&mut current_nouns),
                });
            }

            // Start new entry — extract just the name before any parens or spaces
            let after_prefix = trimmed.strip_prefix("## ").unwrap_or("");
            // Take just the first word (e.g., "frontend" from "frontend (前端)")
            current_expert = after_prefix.split_whitespace().next().unwrap_or("").to_string();
            continue;
        }

        // Parse 主名词: or 主名词 list
        if trimmed.starts_with("主名词:") {
            let nouns_part = trimmed.strip_prefix("主名词:").unwrap_or("");
            for noun in nouns_part.split(',') {
                let noun = noun.trim().to_string();
                if !noun.is_empty() {
                    current_nouns.push(noun);
                }
            }
        } else if current_expert.is_empty() == false && !trimmed.starts_with("##") && !trimmed.starts_with("说明:") {
            // Also parse standalone comma-separated nouns (without prefix)
            for noun in trimmed.split(',') {
                let noun = noun.trim().to_string();
                if !noun.is_empty() && noun.chars().count() >= 2 {
                    current_nouns.push(noun);
                }
            }
        }
    }

    // Save last entry
    if !current_expert.is_empty() && !current_nouns.is_empty() {
        entries.push(PrimaryNounEntry {
            expert_id: current_expert,
            nouns: current_nouns,
        });
    }

    Ok(entries)
}

// ============================================================================
// Negative Signals Loading
// ============================================================================

fn load_negative_signals(path: &Path) -> Result<Vec<NegativeSignalEntry>, ExpertMatchError> {
    if !path.exists() {
        return Ok(Vec::new());
    }

    let content = fs::read_to_string(path)?;
    let mut entries = Vec::new();

    for line in content.lines() {
        let trimmed = line.trim();

        // Skip comments and empty lines
        if trimmed.is_empty() || trimmed.starts_with('#') {
            continue;
        }

        // Parse 触发: ... ; 排除: ...
        if !trimmed.contains("触发:") || !trimmed.contains("排除:") {
            continue;
        }

        // Extract trigger part
        let trigger_part = trimmed.split("排除:").next()
            .and_then(|s| s.split("触发:").last())
            .unwrap_or("")
            .trim()
            .trim_end_matches(';')
            .to_string();

        // Extract exclude part
        let exclude_part = trimmed.split("排除:").last()
            .unwrap_or("")
            .trim()
            .to_string();

        let triggers: Vec<String> = trigger_part
            .split(',')
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty())
            .collect();

        let exclude_experts: Vec<String> = exclude_part
            .split(',')
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty())
            .collect();

        if !triggers.is_empty() && !exclude_experts.is_empty() {
            entries.push(NegativeSignalEntry {
                triggers,
                exclude_experts,
            });
        }
    }

    Ok(entries)
}

// ============================================================================
// Session History Loading (last 10 entries)
// ============================================================================

fn load_last_expert(audit_log: &Path) -> Option<String> {
    if !audit_log.exists() {
        return None;
    }

    let file = File::open(audit_log).ok()?;
    let reader = BufReader::new(file);
    let mut last_expert: Option<String> = None;

    for line in reader.lines().flatten() {
        if let Ok(entry) = serde_json::from_str::<AuditEntry>(&line) {
            last_expert = Some(entry.id);
        }
    }

    last_expert
}

// ============================================================================
// L1a: Keyword Match Scoring
// ============================================================================

fn score_l1a(tokens: &[String], triggers: &[String], kallax_terms: &[&str]) -> u32 {
    let mut score: u32 = 0;

    for token in tokens {
        let token_len = token.chars().count();

        // Skip single character tokens to avoid false positives
        if token_len < 2 {
            continue;
        }

        // Expert-specific trigger match: 30 pts (strong signal)
        for trigger in triggers {
            if token_match(token, trigger) {
                score = score.saturating_add(30);
                break;
            }
        }

        // KALLAX domain dict match: 10 pts (weak signal, used as tiebreaker/recall booster)
        // Lower weight avoids "all experts tied" when KALLAX dict has shared terms
        for term in kallax_terms {
            if token_match(token, term) {
                score = score.saturating_add(10);
                break;
            }
        }
    }

    // Cap at 90 (3 keyword matches = full w1)
    score.min(90)
}

fn token_match(token: &str, candidate: &str) -> bool {
    // 1. Exact match
    if token == candidate {
        return true;
    }

    // 2. Bidirectional substring (token contains candidate OR vice versa)
    if token.contains(candidate) || candidate.contains(token) {
        return true;
    }

    // NOTE: 2-gram window removed — too many false ties (e.g. "数据" matches both
    // backend's "数据库" and security's "数据泄露"). If recall is needed, expand
    // expert triggers or KALLAX dict with explicit short forms instead.

    false
}

// ============================================================================
// L1b Rule 1: Primary Noun Veto
// ============================================================================

fn apply_rule1_primary_nouns(
    candidates: &mut Vec<(String, u32)>,
    tokens: &[String],
    primary_nouns: &[PrimaryNounEntry],
) -> (bool, String) {
    let mut noun_winner = String::new();
    let mut best_hits = 0;

    // Build expert -> nouns map
    let noun_map: HashMap<&str, &[String]> = primary_nouns
        .iter()
        .map(|e| (e.expert_id.as_str(), e.nouns.as_slice()))
        .collect();

    // For each candidate, count how many tokens match their primary nouns
    for (expert_id, _) in candidates.iter() {
        if let Some(nouns) = noun_map.get(expert_id.as_str()) {
            let hits = tokens.iter()
                .filter(|t| nouns.iter().any(|n| t.contains(n) || n.contains(t.as_str())))
                .count();

            if hits > best_hits {
                best_hits = hits;
                noun_winner = expert_id.clone();
            }
        }
    }

    if best_hits > 0 {
        // Apply multiplier: winner × 1.5, others × 0.5
        for (expert_id, score) in candidates.iter_mut() {
            if *expert_id == noun_winner {
                *score = (*score * 3) / 2;  // × 1.5
            } else {
                *score = *score / 2;  // × 0.5
            }
        }
        return (true, noun_winner);
    }

    (false, String::new())
}

// ============================================================================
// L1b Rule 2: Negative Signal Veto
// ============================================================================

fn apply_rule2_negative_signals(
    candidates: &mut Vec<(String, u32)>,
    requirement: &str,
    negative_signals: &[NegativeSignalEntry],
) -> Vec<String> {
    let mut zeroed_experts = Vec::new();

    for entry in negative_signals {
        for pattern in &entry.triggers {
            // Simple substring match (could use regex for more complex patterns)
            if requirement.contains(pattern.as_str()) {
                for expert_id in &entry.exclude_experts {
                    zeroed_experts.push(expert_id.clone());
                    // Set score to 0
                    for (eid, score) in candidates.iter_mut() {
                        if eid == expert_id {
                            *score = 0;
                        }
                    }
                }
                break;
            }
        }
    }

    zeroed_experts
}

// ============================================================================
// L1b Rule 3: Session History Stickiness
// ============================================================================

fn apply_rule3_session_history(
    candidates: &mut Vec<(String, u32)>,
    last_expert: &Option<String>,
) -> bool {
    if let Some(last) = last_expert {
        for (expert_id, score) in candidates.iter_mut() {
            if expert_id == last {
                *score += 5;
                return true;
            }
        }
    }
    false
}

// ============================================================================
// L1b Rule 4: Tiebreaker
// ============================================================================

fn apply_rule4_tiebreaker(candidates: &mut Vec<(String, u32)>) -> bool {
    candidates.sort_by(|a, b| b.1.cmp(&a.1));

    if candidates.len() < 2 {
        return false;
    }

    let best = candidates[0].1;
    let second = candidates[1].1;

    best.saturating_sub(second) < 10
}

// ============================================================================
// L2 Fallback — Fuzzy Search via l1b-router.sh (M6 integration)
// Called when L1b tiebreaker triggers ambiguous=true
// Uses SQLite FTS5 + cosine similarity as second opinion
// ============================================================================

#[derive(Debug, Deserialize)]
struct L2Result {
    best: String,
    score: u32,
    ambiguous: bool,
    reason: String,
}

fn apply_l2_fallback(
    candidates: &[(String, u32)],
    requirement: &str,
    kallax_root: &Path,
) -> Option<(String, u32)> {
    // Build candidates JSON for l1b-router.sh
    let candidates_json: String = candidates
        .iter()
        .map(|(id, score)| format!(r#"{{"id":"{}","score":{}}}"#, id, score))
        .collect::<Vec<_>>()
        .join(",");

    let full_json = format!("[{}]", candidates_json);

    // Call l1b-router.sh
    let l1b_script = kallax_root.join("scripts").join("l1b-router.sh");
    if !l1b_script.exists() {
        return None;
    }

    let output = std::process::Command::new("bash")
        .arg(l1b_script)
        .arg(full_json)
        .arg(requirement)
        .output()
        .ok()?;

    if !output.status.success() {
        return None;
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    let result: L2Result = serde_json::from_str(stdout.trim()).ok()?;

    // L2 threshold: similarity > 0.6 to accept
    // Score 80+ out of 100 maps to > 0.6 similarity
    if result.score > 60 && !result.ambiguous {
        return Some((result.best, result.score));
    }

    None
}

// ============================================================================
// Audit Log Writing
// ============================================================================

fn write_audit_log(audit_log: &Path, entry: &AuditEntry) -> Result<(), ExpertMatchError> {
    // Ensure parent directory exists
    if let Some(parent) = audit_log.parent() {
        fs::create_dir_all(parent)?;
    }

    let json = serde_json::to_string(entry)?;
    let mut file = fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(audit_log)?;
    writeln!(file, "{}", json)?;
    Ok(())
}

// ============================================================================
// Output Formatting
// ============================================================================

fn confidence_from_score(score: u32) -> &'static str {
    if score >= 70 {
        "high"
    } else if score >= 40 {
        "medium"
    } else {
        "low"
    }
}

fn format_human(result: &MatchResult) -> String {
    if result.best_expert == "none" || result.score == 0 {
        format!(
            "L1_MISS via={} id={} score={} confidence={} duration_ms={}\n  reason: {}",
            result.via, result.best_expert, result.score, result.confidence, result.duration_ms, result.reason
        )
    } else {
        format!(
            "MATCHED via={} id={} score={} confidence={} duration_ms={}\n  reason: {}",
            result.via, result.best_expert, result.score, result.confidence, result.duration_ms, result.reason
        )
    }
}

// ============================================================================
// Main Entry Point
// ============================================================================

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = std::env::args().collect();

    if args.len() < 2 || args[1] == "--help" || args[1] == "-h" {
        eprintln!("kallax-expert-match — L1 Expert Matching for KALLAX");
        eprintln!();
        eprintln!("Usage:");
        eprintln!("  kallax-expert-match \"<requirement>\"      # Human-readable output");
        eprintln!("  kallax-expert-match \"<requirement>\" --json  # JSON output");
        eprintln!("  kallax-expert-match --help                  # Show this help");
        eprintln!();
        eprintln!("Environment:");
        eprintln!("  KALLAX_ROOT  Path to .kallax directory (default: auto-detect)");
        return Ok(());
    }

    let requirement = &args[1];
    let json_output = args.get(2).map(|s| s == "--json").unwrap_or(false);

    let start = Instant::now();

    // Resolve paths
    let kallax_root = resolve_kallax_root();
    let expert_dir = resolve_expert_dir(&kallax_root);
    let primary_nouns_path = resolve_primary_nouns_path(&kallax_root);
    let negative_signals_path = resolve_negative_signals_path(&kallax_root);
    let audit_log_path = resolve_audit_log();

    // Initialize jieba with KALLAX dictionary
    let jieba = init_jieba();

    // Tokenize requirement
    let tokens: Vec<String> = jieba
        .cut(requirement, true)
        .iter()
        .filter(|t| !t.trim().is_empty())
        .map(|t| t.to_string())
        .collect();

    // Load experts
    let experts = load_experts(&expert_dir).map_err(|e| format!("Failed to load experts: {}", e))?;

    if experts.is_empty() {
        eprintln!("Error: No experts found in {:?}", expert_dir);
        std::process::exit(1);
    }

    // L1a: keyword match (expert trigger + KALLAX domain dict)
    let mut candidates: Vec<(String, u32)> = experts
        .iter()
        .map(|e| {
            let score = score_l1a(&tokens, &e.trigger, KALLAX_TERMS);
            (e.id.clone(), score)
        })
        .collect();

    // Load L1b resources
    let primary_nouns = load_primary_nouns(&primary_nouns_path).unwrap_or_default();
    let negative_signals = load_negative_signals(&negative_signals_path).unwrap_or_default();
    let last_expert = load_last_expert(&audit_log_path);

    // L1b Rule 1: Primary Noun Veto
    let (noun_mapped, noun_winner) = apply_rule1_primary_nouns(&mut candidates, &tokens, &primary_nouns);

    // L1b Rule 2: Negative Signal Veto
    let zeroed = apply_rule2_negative_signals(&mut candidates, requirement, &negative_signals);

    // L1b Rule 3: Session History
    let history_applied = apply_rule3_session_history(&mut candidates, &last_expert);

    // L1b Rule 4: Tiebreaker
    let ambiguous = apply_rule4_tiebreaker(&mut candidates);

    // M6: L2 Fallback when ambiguous — call l1b-router.sh FTS5 for second opinion
    let mut l2_used = false;
    let mut best_id;
    let mut best_score;

    if ambiguous {
        if let Some((l2_id, l2_score)) = apply_l2_fallback(&candidates, requirement, &kallax_root) {
            best_id = l2_id;
            best_score = l2_score;
            l2_used = true;
        } else {
            // L2 failed or low confidence — fall back to L1 miss
            best_id = "none".to_string();
            best_score = 0;
        }
    } else {
        // Pick best from L1b
        candidates.sort_by(|a, b| b.1.cmp(&a.1));
        (best_id, best_score) = candidates.first().cloned().unwrap_or_else(|| ("none".to_string(), 0));
    }

    // Build reason string
    let mut reason_parts = Vec::new();
    if !tokens.is_empty() {
        reason_parts.push(format!("kw={}", tokens.join("+")));
    }
    if noun_mapped {
        reason_parts.push(format!("noun_veto:{}", noun_winner));
    }
    if !zeroed.is_empty() {
        reason_parts.push(format!("neg:{}", zeroed.join("&")));
    }
    if history_applied {
        reason_parts.push(format!("history:+5({})", last_expert.as_ref().unwrap_or(&String::new())));
    }
    if ambiguous {
        if l2_used {
            reason_parts.push("L2:resolved".to_string());
        } else {
            reason_parts.push("L1_miss:L2_low_confidence".to_string());
        }
    } else {
        reason_parts.push("tiebreak:resolved".to_string());
    }
    let reason = reason_parts.join("; ");

    let via = if l2_used {
        "L2"
    } else if ambiguous {
        "L1b_ambiguous"
    } else if noun_mapped || history_applied || !zeroed.is_empty() {
        "L1b"
    } else {
        "L1a"
    };

    let duration_ms = start.elapsed().as_millis() as u64;

    let result = MatchResult {
        via: via.to_string(),
        best_expert: best_id.clone(),
        score: best_score,
        confidence: confidence_from_score(best_score).to_string(),
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