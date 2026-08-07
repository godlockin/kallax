# EPIC-201: docs audit 极致扩展 — Retrospective (2026-08-07, 补)

> **EPIC-202-B (Process 对抗 review) 补**: EPIC-201 当初写了拍板记录但漏 retrospective。本 retro 补完整。

## Metrics

| 指标 | 数值 |
|------|------|
| 改动 | 5 files (scripts/check-internal-refs.cjs, scripts/post-process.sh, docs/_deprecated-index.md, tests/integration/epic-201-audit-extension-test.sh, confluence/decisions/EPIC-201-audit-extension-2026-08-07.md) |
| Lines | +293/-30 |
| 4-PR | 3 (testing + main + miao, PR #286-288) |
| Stale ref 终态 | 0 (含 web/ scope 后 41 → 0) |

## 4 Lessons

### 1. check-internal-refs scope 扩展是 docs audit 的核心能力
**教训**: 默认仅 .md 漏掉 .html/.json/.txt/.sh 多类文件。EPIC-201 扩到 web/ + root .json 后发现 22 个真 stale (exhibits HTML/JSON 引用不存在的 markdown)。
**应用**: scope 扩展应作为所有 docs audit 工具的 baseline, 跟 EPIC-202-A 一致。

### 2. docs/_deprecated-index.md 维护成本 vs 价值
**教训**: 22 个 DEPRECATED 文件全列索引, 给 reader 一页入口。维护成本: 每次新 DEPRECATED header 必同步追加。
**应用**: 加 CI gate (待建): 检查 DEPRECATED header 文件数 跟 _deprecated-index.md 表格行数一致。

### 3. 拍板记录跟 retrospective 分离
**教训**: EPIC-201 当时只写拍板记录, 没写 retro。导致 EPIC-202-B 触发补 retro (现在)。
**应用**: future EPIC 必走 8-step 流程 step 7 (retrospective), 不能跳。

### 4. CI 失败但仍 merge 是系统性问题
**教训**: EPIC-201 3 PR (#286-288) merge 时 check-body / check-dco / Forbidden Patterns / Security Audit / Test CLI 全失败。
**应用**: PR body template 必填 7-class risk schema + check-dco base SHA 检测 (待 EPIC-202-B 后续修)。

## 跟 EPIC-200 联合

EPIC-200 闭环 100% Read audit, EPIC-201 扩 tools scope + 加 DEPRECATED index.
EPIC-202-A 修 EPIC-199/200/201 期间发现的工具 bug (link text 括号, anchor #?, HTML 结构破坏).

## Rule 联合

- Rule 5 (DRY): 22 DEPRECATED header "archive-not-delete" 字串重复 26 次 — DRY 违规, 待 EPIC-202-C 修
- Rule 9 (KPI): 数字 22 跟 audit agent 报告 25 confluence + 50 docs + 27 根级 .md = 102 有一致 (实际 22 因部分 file已不存在, 还有待 EPIC-202-C audit)
- Rule 35 (Sprint 时间盒): 1 commit ≤ 500 行 ✅

## 8-step 流程

EPIC-201 处于 step 4-5 交接点。本 retro 补 step 7。下一步: cleanup (已 done)。

---

Co-Authored-By: Claude <noreply@anthropic.com>