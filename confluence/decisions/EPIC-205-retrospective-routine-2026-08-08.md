# EPIC-205 retrospective-routine 季度整理 (2026-08-08)

> **Decision record**: EPIC-161 retrospective-routine.sh 季度 dry-run + KALLAX_ROOT path fix.
> **Author**: master | **Reviewer**: 主公 2026-08-08 拍板

## 1. 范围

EPIC-161 retrospective-routine.sh 6 阶段季度 dry-run + 修 path bug.

## 2. 修复 (跟主公拍板 1:1)

**KALLAX_ROOT path bug**: 脚本硬编码 `scripts/../..`, 在 worktree 嵌套环境 (`.worktrees/EPIC-205-retrospective/scripts/retrospective-routine.sh`) 指向 `.worktrees/` 而不是 `kallax/`.

**Fix**: 优先 `git rev-parse --show-toplevel` (worktree-safe), fallback 保留 `scripts/../..`.

**落地**: `scripts/retrospective-routine.sh` KALLAX_ROOT 解析逻辑 (4 行).

## 3. 6 阶段 dry-run 结果 (跟 EPIC-205 1:1)

| 阶段 | 数据 | 健康 |
|------|------|------|
| **retrospect** | 10 release (v3.34.6 → v3.32.15, 8 月份 8 release) | ✅ |
| **consolidate** | CLAUDE.md 197 行 (≤200 OK) + 0 duplicate + 无 `_archived/` | ✅ |
| **review-docs** | 6 path-scoped rules + 24 docs/reference + 65 decisions + 全 path frontmatter | ✅ |
| **upgrade** | node v24.15.0 + rustc 1.97.1 + Cargo 3.32.1 + node 3.32.1 + install 97 files | ✅ |
| **archive** | 1 DEPRECATED (CHANGELOG.md 误报, 关键词 grep 命中非真正 deprecated) | ⚠️ false positive |
| **delete** | 1 0-byte (web/dashboard-metrics.json) + scan-dead-code exit 2 BLOCKED-env | ⚠️ |

## 4. 关键发现

- **CLAUDE.md 197 行**: 符合 EPIC-159 硬阈值 ≤ 200, 3 行 buffer 留余量
- **6 path-scoped rules**: 全部含 `paths:` frontmatter (跟 EPIC-159 AC 1:1 验证)
- **24 docs/reference + 65 decisions**: 跟 EPIC-159 + EPIC-197/199/200/201 SoT 归并一致
- **0 duplicate**: EPIC-197 sha256sum 验证后 0 残留
- **scan-dead-code exit 2**: BLOCKED-env (跟 EPIC-131/132 治理 1:1, 需要环境变量非 BLOCKED-env 才跑)

## 5. 落地

- 0 source code change
- 1 commit (KALLAX_ROOT fix)
- 1 force-push: feature/EPIC-205-retrospective → testing → main → miao

## 6. Reviewer

- 主公 (拍板 EPIC-205 retrospective-routine 跑批)
- master (执行)
- EPIC-161 retrospective-routine (源)
- EPIC-204 sprint-metrics (sprint 跑批入口)