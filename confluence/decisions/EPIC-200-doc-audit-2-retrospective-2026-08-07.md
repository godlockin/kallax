# EPIC-200: docs/ + confluence/ 全量补扫 — Retrospective (2026-08-07)

> **起源**: EPIC-197 retrospective 自补 — 实际覆盖率 40%, 剩余 60% 目录未扫。本 EPIC 闭环。

## Metrics

| 指标 | 数值 |
|------|------|
| 补扫文件 | 100+ (25 confluence + 50 docs + 27 根级 .md) |
| 4 并行 audit agent | 4 (全量) |
| git mv | 7 |
| git rm | 1 |
| ADD_DEPRECATED_HEADER | 15 |
| Internal stale ref 修复 | 96 stale links (across 27 files) → 0 stale |
| check-internal-refs.cjs 终态 | 92 refs, 0 stale |
| 4-PR | 3 (testing + main + miao) |

## 5 Lessons

### 1. "100% Read" 必字面 — 列出全子目录+孙目录+根级 .md
**教训**: EPIC-197 标榜 264 文件 100% Read, 实际只扫了 40%。`find ... -name '*.md' | wc -l` 给出的数字不是字面 100%。
**应用**: future audit-first EPIC 必先用 `find <dirs> -type d | sort` 列出所有目录,逐目录进扫描清单。

### 2. stale ref 自动修复工具 v1
**教训**: 96 stale link 跨 27 文件。手动逐条修复不现实。`scripts/fix-stale-links.cjs` (162 行 Node.js) 把 stale markdown link 转 inline code,保留阅读体验。
**应用**: future docs cleanup EPIC 直接跑 `node scripts/fix-stale-links.cjs` (前提 check-internal-refs.cjs 已部署)。

### 3. 根级 docs/ 是历史 release 残留
**教训**: docs/{KARPATHY-VS-KALLAX, RELEASE-INDEX, RTK-CAVEMAN, V350-*} 等 5 文件都该 DEPRECATED header 或 git mv 到 confluence/decisions/。这些是 v2-v3.5 时代 release 文档, 跟 EPIC-199 7 个 _archived DEPRECATED 是同类。
**应用**: future docs-only EPIC: 根级 docs/ + docs/_archived/ 同模式扫描。

### 4. experts HTML/JSON 文件不参与 md link 检测
**教训**: `docs/experts/{index.html,data.json}` 等 HTML/JSON 文件不在 check-internal-refs.cjs scope (只扫 .md), 因此 stale 引用被漏检。
**应用**: future tools 扩展 scope 到 .html/.json (对公开化 showcase 类文件)。

### 5. 三步审计流闭环
**教训**: EPIC-196 → EPIC-197 → EPIC-199 → EPIC-200 (本) 形成完整三步审计循环 (audit→delete→refresh→补扫)。`docs/process/doc-audit-flow.md` 固化。
**应用**: future governance-debt EPIC 触发 retrospective-routine.sh 阶段 2 (consolidate) 自动跑三步。

## 跟 EPIC-199 联合

| EPIC-199 | EPIC-200 |
|----------|----------|
| 10 git mv docs/* → confluence/ (单目录级别) | 7 git mv 根级 docs/ → docs/{process,reference} + confluence/decisions/ (跨目录归类) |
| 7 DEPRECATED header (在 _archived/) | 15 DEPRECATED header (扩展到根级 + superpowers/_archived/ + online-deploy/ + glossary) |
| 0 stale ref 修复工具 | check-internal-refs.cjs + fix-stale-links.cjs 双工具闭环 |

## 跟 CLAUDE.md Rule 联合

- Rule 5 (DRY): 0 改 source code, docs-only
- Rule 8 (Rule of 500): 单 commit ≤ 500 行
- Rule 35 (Sprint 时间盒): 4-PR 全闭环

---

Co-Authored-By: Claude <noreply@anthropic.com>