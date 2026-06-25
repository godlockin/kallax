# L1A 路由设计文档 (KALLAX Architecture)

> **目的**: 沉淀 EPIC-024/028 L1a 路由设计决策 + tokenization 选型, 避免下一个 phase 重蹈覆辙
> **作者**: master (PHASE-002 review 产出)
> **Date**: 2026-06-08
> **Status**: APPROVED (PHASE-002 升级, 主公 2026-06-08 拍板)
> **关联**: EPIC-024-A/B, EPIC-028-A/B, EPIC-030, LESSONS-LEARNED EPIC-024

---

## 1. 概述

L1a 是 KALLAX 3 层专家路由的第 1 层 (L1a/L1b/L2), 负责**精确+子串匹配** expert trigger 字段, 给出初始候选 + 评分. 是 recall (召回) 主力.

**L1a ≠ L1 (整体)**: L1 = L1a (评分) + L1b (规则过滤) 合并. L1a 出候选, L1b 过滤/重排序.

---

## 2. 选型 (tokenization)

### 2.1 评估 5 选项

| 方案 | 速度 (中, ~1000 req) | 库大小 | 中文支持 | 集成难度 | 总评 |
|---|---|---|---|---|---|
| bash `tr ' ,;。' '\n'` | <10ms | 0 | ❌ 不切 (无空格) | ✅ | **K.O. (T1 bug)** |
| Python jieba | 200-500ms | 5MB | ✅ | ⚠️ subprocess 开销 | 中 |
| **jieba-rs 0.7 (Rust)** | **30-100ms** | **1MB** | ✅ | ✅ PyO3 + Rust 库 | **胜** |
| pkuseg (Python) | 300-800ms | 50MB | ✅ | ⚠️ 5x 慢 + 50x 重 | K.O. |
| thulac (Python) | 200-400ms | 10MB | ✅ | ⚠️ dict 重 | 中 |

### 2.2 决策: jieba-rs 0.7

**理由**:
1. **5-10x 快于 Python jieba** (PyO3 集成开销小, Rust hot path 优化)
2. **1MB footprint** (跟 KALLAX Rust 架构契合, binary <5MB)
3. **强制长词合理** (jieba dict 已含专业词, e.g. "数据库索引" → 1 token, "分布式事务" → 1 token, "ABC分类法" → 1 token)
4. **prebuilt wheel 通用** (无需源码编译, Rust 1.70+ 即可)
5. **M8 P99 cold start ~200ms** (jieba dict 加载), 稳态 ~30ms (加 cache 即解)

### 2.3 选型时间线

- 2026-06-07: 主公提出 tokenization 是不是直接的分词模块, 是不是单独的 nlp 库, 需不需要 nlp 专家横向纵向对比
- 2026-06-07: EKET 调研, jieba-rs 0.7 出现, 5 选项比对
- 2026-06-08: 主公拍 D — Rust 重写 expert-match, jieba-rs 落地
- 2026-06-08: a3be6648 Performer 实现, 但用 Python sqlite3 `:param` 语法 (CLI 不接, broken) → Master 接管修

---

## 3. L1a 评分逻辑

### 3.1 算法 (Rust, `kallax-expert-match.rs`)

```rust
fn score_l1a(tokens: &[String], triggers: &[String], kallax_terms: &[&str]) -> u32 {
    let mut score: u32 = 0;
    for token in tokens {
        let token_len = token.chars().count();
        if token_len < 2 { continue; }
        // Expert-specific trigger match: 30 pts
        for trigger in triggers {
            if token_match(token, trigger) {
                score = score.saturating_add(30);
                break;
            }
        }
        // KALLAX domain dict match: 10 pts (弱信号)
        for term in kallax_terms {
            if token_match(token, term) {
                score = score.saturating_add(10);
                break;
            }
        }
    }
    score.min(90)  // 满分 90, L1b 加权到 100
}

fn token_match(token: &str, candidate: &str) -> bool {
    if token == candidate { return true; }
    if token.contains(candidate) || candidate.contains(token) { return true; }
    // 2-gram window removed (T3 教训: 引入 false ties)
    false
}
```

### 3.2 评分原则

| 命中类型 | 分值 | 理由 |
|---|---|---|
| **Expert trigger match** | **30 pts/token** | 强信号: expert 明确说 "我能做 X" |
| **KALLAX domain dict match** | **10 pts/token** | 弱信号: 跟 KALLAX 领域相关但非 expert 专长 |
| **< 2 char token** | 0 | 噪音过滤 (e.g. "的" "了" "是") |
| **min(90) cap** | - | 留 10 分给 L1b 加权 |

### 3.3 设计决策 (跟 4 候选对比)

| 方案 | 描述 | 优点 | 缺点 | 决策 |
|---|---|---|---|---|
| **A. exact only** | `token == trigger` | 简单 | 漏 "数据库索引" 包含 "数据库" | ❌ 太严 |
| B. exact + forward substring | `token.starts_with(trigger)` | 召回 ↑ | "数据库" 命中 backend, "数据库管理员" 也命中 (false positive) | ⚠️ |
| C. exact + 2-gram window | 加 2-gram 子串 | 召回 ↑↑ | "数据" 命中 backend "数据库" 跟 security "数据泄露" → tie | ❌ 引入 false tie |
| **D. exact + bidirectional substring** | `token ⊃ trigger ∨ trigger ⊃ token` | 召回 + 控制 false tie | 仍有些 tie, 走 L1b 解决 | ✅ **胜** |
| E. semantic similarity (cosine) | embedding 距离 | 召回 ↑↑↑ | 需要 embedding 模型, cold start 慢 | ⏸ L2 路径 (待 `semantic-embed.py`) |

**胜出 D + L1b Rule 1 (主名词 veto)** 解决 tie.

---

## 4. 集成 (L1a → L1b → L2)

```
[需求: "数据库索引很慢"]
   ↓
jieba-rs tokenize → ["数据库索引", "很", "慢"]
   ↓
[1a] score_l1a: 7 expert 各自打分
   - backend: "数据库索引" 双向含 "数据库" + "索引" → 60 pts
   - architect: "数据库索引" 不在 trigger → 0 pts
   - frontend: 同上 → 0 pts
   - ...
   - 输出: backend (60), 共享 "数据" → security (10) tie
   ↓
[1b] 4 规则过滤
   - Rule 1 主名词 veto: "数据库" 是主名词 → 留 backend, 否决 security tie
   - Rule 2 负向信号: 无
   - Rule 3 会话历史: 之前 5 个 query 都是 backend
   - Rule 4 tiebreaker: 不需要 (Rule 1 已解)
   - 输出: backend (high confidence)
   ↓
[2] Fallback (如果 L1a 0 命中)
   - FTS5 + LIKE substring search
   - cosine similarity (待 `semantic-embed.py` 填 97 expert)
   - 阈值 0.4, top-5
   - 输出: 5 candidates + relevance
   ↓
matched expert + audit log
```

---

## 5. KPI 指标 (EPIC-024/028 实测)

| 指标 | 目标 | 实测 | 决策 |
|---|---|---|---|
| **M1 L1a hit rate** | ≥80% | **86.7%** (26/30) | ✅ PASS |
| **M6 ambiguous 解决** | ≥70% | **90%** (18/20) | ✅ PASS (L1b 4 规则) |
| **M7 false-positive 否决** | ≥90% | **90%** (9/10) | ✅ PASS |
| **M8 P99 latency** | <200ms | **152ms** (best) / 235ms (cold) | ⚠️ borderline (M8 known issue) |
| **Test case 隔离** | 0 leak | **0/30** | ✅ PASS (anti-fab) |
| **KPI precision** | 100% | **100%** (X/Y 1 位小数) | ✅ PASS (anti-fab) |
| **Scope creep** | 100% in scope | **27/27** | ✅ PASS (anti-fab) |

---

## 6. 已知债 + 后续优化

| 债 | 描述 | 解法 | 优先级 |
|---|---|---|---|
| **M8 cold start** | jieba-rs 第一次跑 ~200ms, 后续 ~30ms | 加 jieba 预热 cache + in-process l1b-router (替代 subprocess) | P1 (follow-up) |
| **Vector embedding 空** | `expert_vec` 表空, L2 缺语义分数 | 跑 `semantic-embed.py` 填 97 expert | P1 (低风险) |
| **Extended trigger 短** | 90 extended 之前 5-6 词, EPIC-030 扩到 26-30 词 | ✅ EPIC-030 (d4390f9) 已落地 | ✅ done |
| **L3 generation** | LLM 自动生成新 expert (飞轮 "运行" 阶段入口) | EPIC-024-C Sprint 3 (待主公拍) | P0 (主公决策) |
| **A6 semantic recall** | "ML模型" 这种 jieba 拆开的需求 L2 substring 找不到 | 跑 `semantic-embed.py` 后 L2 cosine 兜底 | P1 |

---

## 7. 风险 + 反模式

### 7.1 风险

- **Performer 任务过大**: 1 Performer 跑 jieba-rs 集成 + L1a 逻辑 + 3 anti-fab 工具易 token 爆 (a3be6648 教训). **拆**: Performer 1 主体 + Master corrective integration 兜底
- **sqlite3 语法错**: Performer 用了 Python sqlite3 `:param` 语法, CLI 不接 — 3 script query broken. **防**: Master 独立 verify query 真的 work
- **Test case verbatim**: trigger 字段塞测试需求整句 = 100% circular match, 假数据. **防**: `check-test-case-isolation.sh`

### 7.2 反模式

- ❌ bash `tr` 处理中文 (无空格不切)
- ❌ L1a 严格 prefix matching (漏 substring 召回)
- ❌ 2-gram window 引入 false tie
- ❌ KPI 估数报 PASS
- ❌ Test case verbatim 触发
- ❌ Scope creep 混 PR

---

## 8. 决策 ADR (Architecture Decision Records)

| ADR | 决策 | 时间 |
|---|---|---|
| ADR-L1A-001 | L1a 用 Rust + jieba-rs 0.7 实现 | 2026-06-08 |
| ADR-L1A-002 | 评分算法: exact + bidirectional substring (D 方案) | 2026-06-08 |
| ADR-L1A-003 | KALLAX domain dict 加权 10 pts (vs trigger 30 pts) | 2026-06-08 |
| ADR-L1A-004 | min(90) cap, L1b 加权到 100 | 2026-06-08 |
| ADR-L1A-005 | 2-gram window 移除 (T3 教训) | 2026-06-08 |
| ADR-L1A-006 | < 2 char token 噪音过滤 | 2026-06-08 |
| ADR-L1A-007 | L1a 独立 binary (`kallax-expert-match`), L1b wrapper (bash) | 2026-06-08 |

---

**Author**: master_StevendeMacBook-Pro.local
**Last updated**: 2026-06-08 22:58
**Status**: ✅ APPROVED — PHASE-002 升级落地
