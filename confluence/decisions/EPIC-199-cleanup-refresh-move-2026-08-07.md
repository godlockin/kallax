# EPIC-199 拍板记录 — docs 7 refresh + 10 file 归并 (跟 EPIC-197 联动)

> **日期**: 2026-08-07
> **范围**: 7 docs/_archived refresh (DEPRECATED 段) + 10 file git mv (docs → confluence DRY) + 1 内部合并 (_DEPRECATED.md → _index.md)
> **拍板**: 主公 2026-08-07 "refresh 和归并一起做"
> **联动**: EPIC-197 (confluence+docs 全量审计) + EPIC-198 (docs-only CI exempt)

---

## Summary

EPIC-197 拍板记录 §3.3 列出 7 refresh candidates + 目录分类评估建议归并2 redundancy。本 EPIC-199 一次性处理:

1. **7 refresh**: docs/_archived/*.md 加 DEPRECATED 段 (内容保留, 引用 modern 替代)
2. **10 file 归并**: docs/adr/ + docs/decisions/ + docs/be/ + docs/governance/ + docs/investigation/ + docs/refactor/ + docs/review/ + docs/expert-extension/ → confluence/decisions/ + confluence/memory/lessons/ (DRY 单一 SoT)
3. **1 内部合并**: docs/architecture/_DEPRECATED.md → docs/architecture/_index.md (重叠元数据)

---

## 1. Refresh 7 files (DEPRECATED 段)

| File | 当前状态 | DEPRECATED 段指向 |
|------|----------|-------------------|
| `docs/_archived/phase-index.md` (181L) | v2.7.4, 引用不存在的 KALLAX-GLOSSARY.md | → `confluence/decisions/` + `docs/phase-index.md` 不存在替代 |
| `docs/_archived/phase-review.md` (47L) | v2.0.0, 流程过时 | → `confluence/decisions/workflow-8step-2026-08-07.md` |
| `docs/_archived/KARPATHY-VS-KALLAX-2026-06-27.md` (80L) | v3.0 era, 8 Gap 分析 | → `docs/ARCHITECTURE.md` + 现代框架 |
| `docs/_archived/RELEASE-INDEX.md` (54L) | v3.1-v3.5 release 索引 | → GitHub Releases tab |
| `docs/_archived/RTK-CAVEMAN-KALLAX-2026-06-29.md` (46L) | v3.2 era rtk+caveman 整合 | → `docs/token-economy.md` |
| `docs/_archived/V350-ARCH-DELTA.md` (58L) | v3.5 架构增量 | → 已并入 `docs/ARCHITECTURE.md` |
| `docs/_archived/V350-RELEASE-2026-06-30.md` (40L) | v3.5 release, ERRATA | → 历史 reference |

**DEPRECATED 段格式** (跟现有 `docs/_archived/_DEPRECATED.md` 1:1):

```markdown
> **DEPRECATED (2026-08-07, EPIC-199)**: 内容已过时, 参考 <modern-alternative>
> **保留原因**: 历史 reference, 0 删 (跟 EPIC-196 v2 1:1 archive-not-delete)
```

---

## 2. 归并 10 files (DRY 单一 SoT)

### 2.1 docs/adr/ → confluence/decisions/ (1 file)

| Source | Destination |
|--------|-------------|
| `docs/adr/adr-001-degradation-strategy.md` (185L) | `confluence/decisions/adr-001-degradation-strategy.md` |

### 2.2 docs/decisions/ → confluence/decisions/ (2 files)

| Source | Destination |
|--------|-------------|
| `docs/decisions/epic-132-dead-module-fixup-plan.md` (102L) | `confluence/decisions/EPIC-132-dead-module-fixup-plan.md` |
| `docs/decisions/epic-132-dead-module-fixup-journey.md` (286L) | `confluence/decisions/EPIC-132-dead-module-fixup-journey.md` |

### 2.3 docs/be/ → confluence/memory/lessons/ (1 file)

| Source | Destination |
|--------|-------------|
| `docs/be/BE-28-29-crossrelease-2026-06-25.md` (211L) | `confluence/memory/lessons/BE-28-29-crossrelease-2026-06-25.md` |

### 2.4 docs/governance/ → confluence/memory/lessons/ (1 file)

| Source | Destination |
|--------|-------------|
| `docs/governance/EPIC-062-master-b-consolidation-2026-06-25.md` (110L) | `confluence/memory/lessons/EPIC-062-master-b-consolidation-2026-06-25.md` |

### 2.5 docs/investigation/ → confluence/memory/lessons/ (1 file)

| Source | Destination |
|--------|-------------|
| `docs/investigation/EPIC-040-rootcause-2026-06-25.md` (339L) | `confluence/memory/lessons/EPIC-040-rootcause-2026-06-25.md` |

### 2.6 docs/refactor/ → confluence/memory/lessons/ (2 files)

| Source | Destination |
|--------|-------------|
| `docs/refactor/EPIC-064-split-consolidation-2026-06-25.md` (236L) | `confluence/memory/lessons/EPIC-064-split-consolidation-2026-06-25.md` |
| `docs/refactor/EPIC-065-users-paths-cleanup-2026-06-25.md` (155L) | `confluence/memory/lessons/EPIC-065-users-paths-cleanup-2026-06-25.md` |

### 2.7 docs/review/ → confluence/memory/lessons/ (1 file)

| Source | Destination |
|--------|-------------|
| `docs/review/EPIC-022-A-B-review-2026-06-25.md` (294L) | `confluence/memory/lessons/EPIC-022-A-B-review-2026-06-25.md` |

### 2.8 docs/expert-extension/ → confluence/memory/lessons/ (2 files)

| Source | Destination |
|--------|-------------|
| `docs/expert-extension/EPIC-016-post-review-2026-06-25.md` (492L) | `confluence/memory/lessons/EPIC-016-post-review-2026-06-25.md` |
| `docs/expert-extension/EXPERT-EXTENSION-SPRINT-A-REPORT.md` (204L) | `confluence/memory/lessons/EXPERT-EXTENSION-SPRINT-A-REPORT.md` |

---

## 3. 内部合并 (1 file)

| Action | Details |
|--------|---------|
| `docs/architecture/_DEPRECATED.md` (33L) → `docs/architecture/_index.md` (28L) | 合并内容到 _index.md, 删除 _DEPRECATED.md |

`_DEPRECATED.md` 描述 4 个 DEPRECATED sub-doc 状态,跟 `_index.md` (1 主文档 入口) 重叠。合并后 `_index.md` 包含两层信息。

---

## 4. 引用更新 (跟 EPIC-196 v2 1:1)

10 个 mv 的 file 引用 (jira/epics/ + confluence/ 内部引用), sed 改:
- `docs/adr/` → `confluence/decisions/`
- `docs/decisions/` → `confluence/decisions/`
- `docs/be/` → `confluence/memory/lessons/`
- `docs/governance/` → `confluence/memory/lessons/`
- `docs/investigation/` → `confluence/memory/lessons/`
- `docs/refactor/` → `confluence/memory/lessons/`
- `docs/review/` → `confluence/memory/lessons/`
- `docs/expert-extension/` → `confluence/memory/lessons/`

---

## 5. 工作计划 (跟 EPIC-181 R1-R5 1:1)

| Step | 操作 | Status |
|------|------|--------|
| 1 | 建 worktree `feature/EPIC-199-refresh-move` (main HEAD) | ✅ |
| 2 | 10 git mv (docs → confluence) | ✅ |
| 3 | sed 改内部引用 (~10 file) | ⏸ |
| 4 | 内部合并 `_DEPRECATED.md` → `_index.md` | ⏸ |
| 5 | 7 refresh 加 DEPRECATED 段 | ⏸ |
| 6 | 写 EPIC-199 拍板记录 (本文件) | ✅ |
| 7 | 测试: grep stale-ref 验证 (跟 epic-197 1:1) | ⏸ |
| 8 | commit + PR (feature → testing → main → miao) | ⏸ |

---

## 6. 验证

- 10 git mv (rename, git history 保留)
- 7 DEPRECATED 段 (内容 + 现代引用)
- 1 内部合并
- 0 source code change
- 0 CLAUDE.md / README / CHANGELOG change (除新增 EPIC-199 entry)
- 0 增 Rule / immutable script

---

## 7. 联动

- **EPIC-197**: docs-only 实例触发3 规范 fail → EPIC-198 治理 → EPIC-199 归并
- **EPIC-198**: docs-only CI exempt (跟 EPIC-199 docs-only PR 1:1)
- **EPIC-196 v2**: 拍板记录模式 + cherry-pick 备案
- **EPIC-142/146/155/176**: 4-PR force-push 模式
- **Rule 5 DRY**: docs/confluence 单一 SoT 原则

---

## 8. Reviewer

- 主公 (拍板)
- master (执行)

**Last updated**: 2026-08-07 (EPIC-199 拍板记录 v1)