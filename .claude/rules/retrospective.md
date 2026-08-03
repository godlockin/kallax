---
paths:
  - scripts/retrospective-routine.sh
  - scripts/post-process.sh
  - confluence/decisions/**
---

# Retrospective Routine (EPIC-161)

> **Path-scoped rule**: 只在 retrospective / post-process script 或 confluence/decisions 修改时加载.

## 6 阶段 (主公 2026-08-03 拍板)

| # | 阶段 | 触发 | 工具 |
|---|------|------|------|
| 1 | **retrospect** (复盘) | release | 列最近 N release, bugs / regressions / decisions |
| 2 | **consolidate** (整理) | quarter | 合并重复 docs / 移除 dead refs / 压缩 oversized files |
| 3 | **review-docs** (review 文档) | governance-debt | 验证 lazy-load refs / path-scoped rules / docs/reference/ |
| 4 | **upgrade** (升级) | quarter | deps outdated / tool version / install.sh Omnibus |
| 5 | **archive** (归档) | governance-debt | 移 deprecated → `_archived/` (跟 v3.32.0 38 docs 1:1) |
| 6 | **delete** (删除) | governance-debt | 0-use files / unused exports / dead scripts |

## Usage

```bash
# Dry-run (default, fail-safe)
scripts/retrospective-routine.sh

# Apply
scripts/retrospective-routine.sh --apply

# 部分跑
scripts/retrospective-routine.sh --stages=retrospect,archive

# Trigger mode
scripts/retrospective-routine.sh --phase=release
scripts/retrospective-routine.sh --phase=quarter
scripts/retrospective-routine.sh --phase=governance-debt

# JSON 输出
scripts/retrospective-routine.sh --json
```

## 跟 Post-Process 11 步骤 1:1 互补

| 触发 | EPIC | Routine |
|------|------|---------|
| EPIC/Sprint 完成 | EPIC-059-E Post-Process 11 步骤 | 自动 |
| 阶段 / 季度 / 治理债 threshold | **EPIC-161 Retrospective Routine** | manual / schedule |

## 0 改 Rule, 0 增 immutable script

跟 install.sh Omnibus (EPIC-160) 1:1 pattern. install.sh 自动 install retrospective-routine.sh.

## Reference

- EPIC-161 ticket: `jira/tickets/EPIC-161/`
- Tests: `bash tests/integration/retrospective-routine.test.sh` (17/17 PASS)
- Inventory: `bash scripts/retrospective-routine.sh --json`
- 跟 EPIC-059-E Post-Process 1:1 兼容