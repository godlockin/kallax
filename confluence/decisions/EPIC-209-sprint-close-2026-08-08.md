# EPIC-209 Sprint 闭环 (2026-08-08)

> **Decision record**: retrospective-routine --apply + CLAUDE.md trim 188 行 + _deprecated-index.md 23 entries.
> **作者**: master | **审核**: 主公 2026-08-08 拍板

## 1. 范围

3 件事并行 (跟主公"123 并行开工"拍板 1:1):
1. retrospective-routine `--apply` 实际跑批 (跟 EPIC-205 dry-run 闭环)
2. CLAUDE.md trim 211 → 188 行 (EPIC-159 ≤ 200 阈值合规)
3. `_deprecated-index.md` 22 → 23 entries (ARCHITECTURE.md DEPRECATED redirect 跟 EPIC-206 1:1)

## 2. 落地

### 2.1 retrospective-routine --apply 跑批

```bash
bash scripts/retrospective-routine.sh --apply
```

**结果**:
- retrospect: 10 release top (v3.34.6 → v3.32.15)
- consolidate: CLAUDE.md **211 行** (> 200 阈值, 触发 trim 需求, 跟 EPIC-205 dry-run 一致)
- review-docs: 6 path-scoped rules + 24 docs/reference + 69 decisions
- upgrade: node v24.15.0 + rustc 1.97.1 + install 97 files
- archive: ✓ Created `_archived/` directory (跟 EPIC-205 dry-run "不存在" 闭合)
- delete: 1 0-byte (web/dashboard-metrics.json) + scan-dead-code exit 2 BLOCKED-env

### 2.2 CLAUDE.md trim (211 → 188 行)

EPIC-208 累计加了 §6 5 行 EPIC + §5.1/5.2 备案债段, 触发 EPIC-159 阈值突破. EPIC-209 trim 方案 (跟 EPIC-159 path-scoped lazy load 1:1):

| 拆出 | 移到 | 行数 |
|------|------|------|
| §6 Recent EPICs (24 EPIC 表) | `.claude/rules/recent-epics.md` | 49 → 5 (CLAUDE.md 减少 44 行) |

**新增 path-scoped rule**: `.claude/rules/recent-epics.md` (61 行, EPIC-209 创建), path-scoped `paths: [CLAUDE.md]` 跟 EPIC-159 联合.

**CLAUDE.md 211 → 188 行**, EPIC-159 阈值 (≤ 200) 合规, buffer 12 行留余量.

### 2.3 _deprecated-index.md 23 entries

跟 EPIC-206 ARCHITECTURE.md DEPRECATED redirect 1:1:
- 22 → 23 entries (新增 `docs/ARCHITECTURE.md` 条目)
- 5 个根级 docs/ 条目现代替代全部更新为 `confluence/manifesto/01-top-design.md` (跟 EPIC-206 SoT 归并 1:1)

## 3. 0 改 source code / 0 增 Rule / 0 增 immutable script

跟 EPIC-197/199/200/201/202-A/B/C/203-208 docs-only EPIC 1:1 pattern.

## 4. 4-PR 流程 (本 EPIC-209 自身, 严格 4 段 EPIC-207 v2)

| 阶段 | 操作 | 验证 |
|------|------|------|
| Step 1 | feature/EPIC-209-sprint-close (worktree) | 3 文件 diff (CLAUDE.md + recent-epics.md + _deprecated-index.md) |
| Step 2 | PR-1: feature → testing | master review + comment |
| Step 3 | PR-2: testing → main | **FF push + master review comment** (跟 EPIC-207 v2 §5.1 1:1) |
| Step 4 | PR-3: main → miao | 独立 PR + master review |

## 5. Reviewer

- 主公 (拍板"123 并行开工")
- master (执行)
- EPIC-205 + EPIC-206 (源)
- EPIC-207 v2 (4-PR strict 1:1)