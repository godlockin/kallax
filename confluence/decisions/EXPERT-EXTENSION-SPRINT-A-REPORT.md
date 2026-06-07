# EXPERT-EXTENSION Sprint A Report

> **EPIC**: EPIC-024 (EXPERT-EXTENSION)
> **Phase**: Sprint A (validate_first)
> **Date**: 2026-06-07
> **Status**: DECISION GATE - Sprint B Required

---

## Executive Summary

**Decision**: EXPAND - Sprint B Recommended

**L1 Hit Rate (threshold >=2)**: 0.0% (0 hit / 117 total)
**L1 Miss Rate**: 100.0% (exceeds 30% threshold)

8专家共识 validate_first 的 hard data 已落地。当前 keyword set 与实际 ticket 描述不匹配，需要 Sprint B 扩展关键词库。

---

## Phase 1: Data Collection

### 1.1 Baseline Data

- **Source**: EPIC-016 (17 tickets) + EPIC-021 (6 tickets) = 25 tickets
- **Collection Method**: l1-extract-keywords.sh (scripts/extension/)
- **Output**: `.kallax/data/expansion/l1-baseline-data.json`

### 1.2 JSON Schema

```json
{
  "ticket_id": "EPIC-016-A",
  "expert": "unknown",           // resolved from symptom keywords
  "title": "写 benchmark-init.sh...",
  "description_keywords": {
    "backend": "",
    "frontend": "",
    "architect": "",
    "product": "",
    "ux": ""
  },
  "actual_expert": "unknown" // from review field or resolved
}
```

### 1.3 Keyword Source

Expert trigger keywords extracted from `.kallax/experts/INDEX.md` symptom table:

| Expert | Symptom Keywords |
|--------|------------------|
| backend | 接口响应慢, 列表加载, 卡顿, 查询, 数据库, 后端, 服务端, API |
| frontend | 页面卡顿, 组件错位, 前端, UI, 界面卡, 加载慢, 渲染, 样式 |
| architect | 架构选型, 模块边界, 抽象层, 设计, 结构, 重构 |
| product | 优先级, 功能该不该做, 砍哪个, 产品, 决策 |
| ux | 界面操作, 文案, 按钮找不到, UX, 用户体验, 交互 |

---

## Phase 2: Match Test Execution

### 2.1 Test Configuration

- **Tool**: l1-match-test.sh (scripts/extension/)
- **Strategies**: 3 (exact, substring, threshold)
- **Experts**: 5 (backend, frontend, architect, product, ux)
- **Total Matches**: 5 experts × 25 tickets × 3 strategies = 375 match attempts

### 2.2 Strategy Definitions

| Strategy | Logic |
|----------|-------|
| exact | Keyword matches as whole word (case insensitive) |
| substring | Keyword appears as substring in text |
| threshold | >=2 keyword hits triggers match |

### 2.3 Results Table

#### Per-Expert Hit Rates

| Expert | Strategy | Hit | Miss | Rate |
|--------|----------|-----|------|------|
| backend | exact | 0 | 23 | 0.0% |
| backend | substring | 0 | 23 | 0.0% |
| backend | threshold | 0 | 23 | 0.0% |
| frontend | exact | 1 | 23 | 4.2% |
| frontend | substring | 1 | 23 | 4.2% |
| frontend | threshold | 0 | 24 | 0.0% |
| architect | exact | 0 | 23 | 0.0% |
| architect | substring | 0 | 23 | 0.0% |
| architect | threshold | 0 | 23 | 0.0% |
| product | exact | 1 | 23 | 4.2% |
| product | substring | 1 | 23 | 4.2% |
| product | threshold | 0 | 24 | 0.0% |
| ux | exact | 0 | 23 | 0.0% |
| ux | substring | 0 | 23 | 0.0% |
| ux | threshold | 0 | 23 | 0.0% |

#### Overall Hit Rates

| Strategy | Hit | Miss | Rate |
|----------|-----|------|------|
| exact | 2 | 115 | 1.7% |
| substring | 2 | 115 | 1.7% |
| threshold | 0 | 117 | 0.0% |

---

## Phase 3: Decision

### 3.1 Decision Criteria

Per 8专家共识:
- L1 miss rate < 30% → **VALIDATE** (no expansion)
- L1 miss rate > 30% → **EXPAND** (Sprint B required)

### 3.2 Current Results

- **Overall L1 Hit Rate (threshold)**: 0.0%
- **Overall L1 Miss Rate (threshold)**: 100.0%
- **Decision**: **EXPAND**

### 3.3 Rationale

The current keyword set from INDEX.md symptom table is designed for **user-facing problem descriptions** (e.g., "接口响应慢", "页面卡顿"), but the actual ticket titles are **technical implementation descriptions** (e.g., "写 benchmark-init.sh", "重写 kallax-init.md").

This is a fundamental mismatch: L1 trigger is designed for users describing problems, not for tickets describing features/refactors.

---

## Phase 4: Sprint B Recommendations

### 4.1 Root Cause

INDEX.md symptom keywords are **user language** (what the user perceives), not **ticket language** (what the developer writes).

### 4.2 Sprint B Options

#### Option A: Expand Keyword Set (Recommended)
Add technical keywords mapped to each expert:

| Expert | Technical Keywords |
|--------|-------------------|
| backend | benchmark, init, script, bash, performance, token |
| frontend | render, ascii, card, stdout, display |
| architect | refactor, architecture, module, design, structure |
| product | feature, priority, decision, roadmap |
| ux | interaction, workflow, step, user flow |

#### Option B: Dual-Layer Matching
- L1a: User symptom keywords (current)
- L1b: Technical implementation keywords (new)

#### Option C: ML-Based Classification
Train a classifier on the25 ticket baseline with actual_expert labels.

### 4.3 Sprint B Scope (Proposed)

1. Create technical keyword map per expert (from EPIC-016/021 title analysis)
2. Run match test with dual-layer keywords
3. Generate EXPERT-EXTENSION-SPRINT-B-REPORT.md
4. Decision: VALIDATE vs EXPAND vs ABANDON

### 4.4 Estimated Effort

- Sprint B: 2h (same as Sprint A)
- Sprint C (if needed): 2h

---

## Appendix: Raw Data

### A.1 Scripts Created

- `scripts/extension/l1-extract-keywords.sh` - Baseline data extraction
- `scripts/extension/l1-match-test.sh` - L1 match test runner

### A.2 Files Modified

- `.kallax/data/expansion/l1-baseline-data.json` - 25 ticket baseline

### A.3 Known Limitations

1. **Keyword Noise**: Current keywords extracted from INDEX.md may include irrelevant terms
2. **Unknown Classification**: 23/25 tickets classified as "unknown" due to symptom mismatch
3. **Single Source**: Only EPIC-016/021 used for baseline (may not represent all ticket types)

---

## Conclusion

Sprint A hard data confirms that the current L1 trigger keyword set is insufficient for matching against technical ticket descriptions. Sprint B should expand the keyword set to include both user-symptom and technical-implementation keywords.

**Next Step**: Master review + Sprint B approval

---

*Report generated: 2026-06-07*
*Performer: performer-EPIC-024*
*Worktree: .kallax/worktrees/performer-EPIC-024*