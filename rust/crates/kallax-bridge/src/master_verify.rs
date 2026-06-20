// rust/crates/kallax-bridge/src/master_verify.rs — KALLAX Master Verify 6-Dimension Bridge
//
// EPIC-060-B 阶段 3 子任务 4: Node.js ↔ Rust 6-dimension master-verify bridge
// 跟 node/src/core/master-verify/dimensions.ts 1:1 mapping (L1-L6)
// 跟 eket 4 级降级 模式 联合: L1 Rust 主用 + L2 Node.js 备
// 跟 AGENTS.md 9 hard rules 联合:
//   Rule 4: 0 magic numbers (所有常量 BRIDGE_VERSION / MAX_FILE_BYTES / KPI_FAB_BLACKLIST 都 已命名)
//   Rule 5: 0 console.log (tracing macro 替代, 跟 observable 联合)
//   Rule 7: 0 commented-out code (干净 1 file 1 set)
//   Rule 8: 0 copy-paste (1 struct + 6 independent functions, 共享 evidence collection helper)
//   Rule 10: 0 mock integration (real file io via std::fs, real regex via regex crate)
//
// 6 维度 (跟 Master L1-L6 联合, 跟 v2.7.4 D4 联合):
//   L1 Existence     — file exists, non-empty, readable
//   L2 Substance     — no TODO/stub/placeholder patterns
//   L3 Wiring        — 关键 import/export marker present
//   L4 DataFlow      — 0 obvious data flow anti-patterns (silent catch, any type)
//   L5 FactForcing   — 5 extended groups wired (security/compliance/audit/process/decision-gate)
//   L6 Honesty       — 0 KPI fabrication patterns (fake_pass / verifies_artifact / mocks_real_check / snapshot_only / always_passes)

use crate::error::BridgeError;
#[cfg(feature = "napi-bindings")]
use napi_derive::napi;
use regex::Regex;
use serde::Serialize;
use std::fs;
use std::path::Path;

/// Bridge version — 跟 v2.7.4 + EPIC-060-B 联合, 显式常量 0 magic numbers.
pub const BRIDGE_VERSION: &str = "kallax-bridge/0.1.0 (EPIC-060-B-3-4, 6-dim, 2026-06-19)";

/// Max file size to scan — 8 MiB. 文件 超过 此 上限 → FileTooLarge 错误.
/// 跟 "不埋坑 / 长期提升优先" 战略 联合: 防止 OOM on huge files.
pub const MAX_FILE_BYTES: u64 = 8 * 1024 * 1024;

/// 5 KPI fabrication patterns (跟 node constants.ts KPI_FAB_BLACKLIST 1:1 联合).
/// 跟 Master L6 Honesty 联合, 跟 EPIC-059-D Fact-Forcing 联合.
const KPI_FAB_BLACKLIST: &[&str] = &[
    "fake_pass",
    "verifies_artifact",
    "mocks_real_check",
    "snapshot_only",
    "always_passes",
];

/// 5 extended expert groups (跟 node constants.ts FIVE_EXTENDED_GROUPS 1:1 联合).
/// 跟 Master L5 FactForcing 联合, 跟 v2.0.3 EPIC-056-A 联合.
const FIVE_EXTENDED_GROUPS: &[&str] = &[
    "security-tool-bypass",
    "process-engineering",
    "auditor",
    "compliance",
    "decision-gate",
];

/// Substantive anti-patterns (跟 Master L2 联合, 跟 dimensions.ts checkL2 placeholder patterns 1:1).
/// 跟 Rule 10 (real tests) 联合: 这些 是 真 placeholder 信号, 0 假阳性 误判.
/// 跟 Rust regex 限制 联合: 0 look-around, 仅 1-step match.
const PLACEHOLDER_PATTERNS: &[&str] = &[
    r"//\s*TODO\b",
    r"function\s+\w+\(\)\s*\{\s*//\s*placeholder",
    r#"throw new Error\(['"]not implemented"#,
];

/// Wiring markers (跟 Master L3 联合): 文件 必须 至少 含 1 个 真实 import / export.
/// 跟 Rust regex (?m) flag 联合: ^ = line start, multi-line content 匹配.
const WIRING_MARKERS: &[&str] = &[
    r"(?m)^\s*use\s+",                  // Rust use
    r"(?m)^\s*pub\s+(fn|struct|enum|mod|use)\b", // Rust pub
    r"(?m)^\s*import\s+",               // TS/JS import
    r"(?m)^\s*export\s+",               // TS/JS export
    r"(?m)^\s*fn\s+\w+\(",              // Rust fn
    r"(?m)^\s*(pub\s+)?(async\s+)?fn\s+\w+", // Rust async fn
    r"(?m)^\s*(export\s+)?(async\s+)?function\s+\w+", // JS/TS function
    r"(?m)^\s*(export\s+)?class\s+\w+", // JS/TS class
];

/// Data flow anti-patterns (跟 Master L4 联合, 跟 Rule 2 + Rule 18 反模式黑名单 联合).
/// 跟 Rust regex 限制 联合: 0 look-around, 仅 1-step match.
const DATAFLOW_ANTIPATTERNS: &[&str] = &[
    r"catch\s*\([^)]*\)\s*\{\s*\}",   // silent catch (empty body)
    r":\s*any\b",                      // `any` type bypass
    r"//\s*eslint-disable",           // ignored lint
    r"//\s*@ts-ignore",               // ignored type error
];

/// Single dimension result (serializable for napi bridge).
///
/// 跟 node helpers.ts DimensionResult 1:1 mapping (joined naming).
/// 跟 Rule 4 (no magic numbers) 联合: 显式 field, 0 隐含 tuple.
#[cfg_attr(feature = "napi-bindings", napi(object))]
#[derive(Debug, Clone, Serialize)]
pub struct DimensionResult {
    pub passed: bool,
    pub dimension: String,
    pub description: String,
    pub evidence: Vec<String>,
}

/// Aggregated 6-dimension result for `verify_all`.
///
/// 跟 Rule 8 (no copy-paste) 联合: 1 struct + 6 results + summary fields.
#[cfg_attr(feature = "napi-bindings", napi(object))]
#[derive(Debug, Clone, Serialize)]
pub struct MasterVerifyResult {
    pub passed: bool,
    pub total_passed: u32,
    pub total_dimensions: u32,
    pub l1: DimensionResult,
    pub l2: DimensionResult,
    pub l3: DimensionResult,
    pub l4: DimensionResult,
    pub l5: DimensionResult,
    pub l6: DimensionResult,
    pub bridge_version: String,
}

/// Static helper struct — 跟 Rule 8 (no copy-paste) 联合:
///   1 struct + 6 独立 function, 共享 read_limited helper.
/// 跟 eket 4 级降级 模式 联合: L1 Rust 主用, L2 Node.js 备 (per-fn 失败 → 上抛 typed error).
pub struct MasterVerifyBridge;

impl MasterVerifyBridge {
    // -----------------------------------------------------------------------
    // L1: Existence — file exists, non-empty, readable
    // -----------------------------------------------------------------------
    pub fn verify_l1_existence(path: &str) -> Result<DimensionResult, BridgeError> {
        let content = Self::read_limited(path, "L1")?;
        let evidence = vec![
            format!("path={}", path),
            format!("size={}B", content.len()),
            format!("non_empty={}", !content.is_empty()),
        ];
        let passed = !content.is_empty();
        Ok(DimensionResult {
            passed,
            dimension: "L1".to_string(),
            description: if passed {
                format!("File exists and non-empty ({}B)", content.len())
            } else {
                "File is empty (failed L1 existence)".to_string()
            },
            evidence,
        })
    }

    // -----------------------------------------------------------------------
    // L2: Substance — no TODO/stub/placeholder patterns
    // -----------------------------------------------------------------------
    pub fn verify_l2_substance(path: &str) -> Result<DimensionResult, BridgeError> {
        let content = Self::read_limited(path, "L2")?;
        let mut hits: Vec<String> = Vec::new();
        for pat in PLACEHOLDER_PATTERNS {
            let re = Regex::new(pat).map_err(|e| BridgeError::regex("L2 pattern compile", e))?;
            if let Some(m) = re.find(&content) {
                hits.push(format!("pattern: {} → match: {}", pat, &m.as_str()[..m.as_str().len().min(80)]));
            }
        }
        let passed = hits.is_empty();
        Ok(DimensionResult {
            passed,
            dimension: "L2".to_string(),
            description: if passed {
                "No placeholder/TODO patterns detected".to_string()
            } else {
                format!("{} placeholder pattern(s) detected", hits.len())
            },
            evidence: if passed {
                vec!["clean".to_string()]
            } else {
                hits
            },
        })
    }

    // -----------------------------------------------------------------------
    // L3: Wiring — at least 1 import/export/fn marker
    // -----------------------------------------------------------------------
    pub fn verify_l3_wiring(path: &str) -> Result<DimensionResult, BridgeError> {
        let content = Self::read_limited(path, "L3")?;
        let mut markers_found: Vec<String> = Vec::new();
        for pat in WIRING_MARKERS {
            let re = Regex::new(pat).map_err(|e| BridgeError::regex("L3 pattern compile", e))?;
            if re.is_match(&content) {
                markers_found.push(pat.to_string());
            }
        }
        let passed = !markers_found.is_empty();
        let evidence = if passed {
            vec![format!("markers_found={}", markers_found.len())]
        } else {
            vec!["no_wiring_markers".to_string()]
        };
        Ok(DimensionResult {
            passed,
            dimension: "L3".to_string(),
            description: if passed {
                format!("Wiring present ({} marker(s))", markers_found.len())
            } else {
                "No wiring markers (no import/export/fn)".to_string()
            },
            evidence,
        })
    }

    // -----------------------------------------------------------------------
    // L4: DataFlow — 0 silent catch / any bypass / @ts-ignore
    // -----------------------------------------------------------------------
    pub fn verify_l4_data_flow(path: &str) -> Result<DimensionResult, BridgeError> {
        let content = Self::read_limited(path, "L4")?;
        let mut hits: Vec<String> = Vec::new();
        for pat in DATAFLOW_ANTIPATTERNS {
            let re = Regex::new(pat).map_err(|e| BridgeError::regex("L4 pattern compile", e))?;
            if re.is_match(&content) {
                hits.push(pat.to_string());
            }
        }
        let passed = hits.is_empty();
        Ok(DimensionResult {
            passed,
            dimension: "L4".to_string(),
            description: if passed {
                "No data-flow anti-patterns".to_string()
            } else {
                format!("{} anti-pattern(s): silent catch / any / @ts-ignore", hits.len())
            },
            evidence: if passed {
                vec!["clean".to_string()]
            } else {
                hits
            },
        })
    }

    // -----------------------------------------------------------------------
    // L5: FactForcing — 5 extended groups referenced
    // -----------------------------------------------------------------------
    pub fn verify_l5_fact_forcing(path: &str) -> Result<DimensionResult, BridgeError> {
        let content = Self::read_limited(path, "L5")?;
        let mut presence: Vec<String> = Vec::new();
        for group in FIVE_EXTENDED_GROUPS {
            let needle = format!("extended/{}", group);
            presence.push(format!("{}:{}", group, if content.contains(&needle) { "present" } else { "missing" }));
        }
        let all_present = presence.iter().all(|p| p.ends_with(":present"));
        Ok(DimensionResult {
            passed: all_present,
            dimension: "L5".to_string(),
            description: if all_present {
                "All 5 extended groups referenced".to_string()
            } else {
                "Some extended groups missing".to_string()
            },
            evidence: presence,
        })
    }

    // -----------------------------------------------------------------------
    // L6: Honesty — no KPI fabrication patterns
    // -----------------------------------------------------------------------
    pub fn verify_l6_honesty(path: &str) -> Result<DimensionResult, BridgeError> {
        let content = Self::read_limited(path, "L6")?;
        let lower = content.to_lowercase();
        let mut found: Vec<String> = Vec::new();
        for pattern in KPI_FAB_BLACKLIST {
            if lower.contains(pattern) {
                found.push((*pattern).to_string());
            }
        }
        let passed = found.is_empty();
        Ok(DimensionResult {
            passed,
            dimension: "L6".to_string(),
            description: if passed {
                "No KPI fabrication patterns".to_string()
            } else {
                format!("KPI fabrication pattern(s): {}", found.join(", "))
            },
            evidence: if passed {
                vec!["clean".to_string()]
            } else {
                found
            },
        })
    }

    // -----------------------------------------------------------------------
    // verify_all — aggregate L1..L6
    // -----------------------------------------------------------------------
    pub fn verify_all(path: &str) -> Result<MasterVerifyResult, BridgeError> {
        let l1 = Self::verify_l1_existence(path)?;
        let l2 = Self::verify_l2_substance(path)?;
        let l3 = Self::verify_l3_wiring(path)?;
        let l4 = Self::verify_l4_data_flow(path)?;
        let l5 = Self::verify_l5_fact_forcing(path)?;
        let l6 = Self::verify_l6_honesty(path)?;
        let results = [&l1, &l2, &l3, &l4, &l5, &l6];
        let total_passed = results.iter().filter(|r| r.passed).count() as u32;
        let total_dimensions = results.len() as u32;
        let passed = total_passed == total_dimensions;
        Ok(MasterVerifyResult {
            passed,
            total_passed,
            total_dimensions,
            l1: l1.clone(),
            l2: l2.clone(),
            l3: l3.clone(),
            l4: l4.clone(),
            l5: l5.clone(),
            l6: l6.clone(),
            bridge_version: BRIDGE_VERSION.to_string(),
        })
    }

    // -----------------------------------------------------------------------
    // read_limited — shared file reader with size cap (跟 MAX_FILE_BYTES 联合)
    // -----------------------------------------------------------------------
    fn read_limited(path: &str, dimension: &'static str) -> Result<String, BridgeError> {
        let p = Path::new(path);
        let meta = fs::metadata(p).map_err(|e| BridgeError::io(dimension, e))?;
        let size = meta.len();
        if size > MAX_FILE_BYTES {
            return Err(BridgeError::FileTooLarge {
                size,
                limit: MAX_FILE_BYTES,
            });
        }
        if size == 0 {
            return Ok(String::new());
        }
        fs::read_to_string(p).map_err(|e| BridgeError::io(dimension, e))
    }
}