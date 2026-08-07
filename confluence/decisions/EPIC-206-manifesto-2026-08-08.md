# EPIC-206 manifesto 5 文件落地 (2026-08-08)

> **Decision record**: 战略文档归一到 `confluence/manifesto/`, 5 文件覆盖顶层设计/scope/时间线/教训/最佳实践.
> **作者**: master | **审核**: 主公 2026-08-08 拍板

## 1. 背景

主公诉求: 找 1 个地方放顶层设计 / scope mission vision 价值观 / 项目时间线 / 经验教训 / 最佳实践.

**现状** (跟 EPIC-205 6 阶段跑批 1:1 验证):
- 顶层设计: docs/ARCHITECTURE.md (v3.0.0 时代 467 行, 部分已迁移)
- scope/mission/vision: ❌ 0 专门文档
- 时间线: CHANGELOG.md (raw 节点, 缺高阶视图)
- 经验教训: confluence/memory/lessons/ (raw, 缺索引)
- 最佳实践: ❌ 0 专门文档 (散在 confluence/decisions/)

## 2. Fix

**新建 `confluence/manifesto/` 顶层目录** (跟 EPIC-197 SoT 归并一致), 5 文件 1:1 覆盖:

| # | 文件 | 行数 | 来源 |
|---|------|------|------|
| 1 | `confluence/manifesto/01-top-design.md` | ~150 | docs/ARCHITECTURE.md (v3.0.0 era) → 当前 v3.34.6 |
| 2 | `confluence/manifesto/02-scope-mission-vision.md` | ~100 | 新建 (跟 EPIC-171/172 1:1 联合) |
| 3 | `confluence/manifesto/03-timeline.md` | ~120 | CHANGELOG.md (raw) → 高阶里程碑视图 |
| 4 | `confluence/manifesto/04-lessons.md` | ~150 | confluence/memory/lessons/ (raw) → 索引 |
| 5 | `confluence/manifesto/05-best-practices.md` | ~180 | 19 EPIC (157-187) 实战 + 5-Level + 4-PR + 4 北极星 + 5 immutable |

**SoT 归并**: docs/ARCHITECTURE.md 加 DEPRECATED header (4 行) + redirect 到 manifesto/01-top-design.md.

## 3. 落地

- 5 manifesto 文件创建
- docs/ARCHITECTURE.md 加 DEPRECATED header
- 0 改 source code / 0 改 Rule / 0 增 immutable script
- 0 增 runtime dependency

## 4. 4-PR 流程

| 阶段 | 操作 | 验证 |
|------|------|------|
| Step 1 | feature/EPIC-206-manifesto (worktree) | 5 manifesto 文件 + DEPRECATED header |
| Step 2 | PR feature → testing | integration test + check-internal-refs |
| Step 3 | testing → main | force-push |
| Step 4 | main → miao | ff merge |

## 5. 联动

- **EPIC-197/199/200/201**: 5-Phase audit flow (SoT 归并 pattern 1:1)
- **EPIC-205**: 6 阶段 retrospective (跑批验证 CLAUDE.md 197 行 + 6 rules + 24 reference + 65 decisions)
- **EPIC-159**: CLAUDE.md 治理 2.0 (lazy load 入口)
- **EPIC-171/172**: 战略沉淀 (3 视角 + growth loop, 跟 scope/vision 1:1)
- **Rule 5 DRY**: 5 文件归一, 0 重复

## 6. Reviewer

- 主公 (拍板 5 文件全建)
- master (执行)
- EPIC-197/199/200/201 SoT 归并 (pattern 1:1)
- EPIC-205 retrospective (6 阶段跑批验证基础)