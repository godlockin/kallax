# EPIC-214 README 重整理 (2026-08-08)

> **Decision record**: README.md 删 3 段重复 + 修 6 处不准确数据, 463 → 157 行 (-66%).
> **作者**: master | **审核**: 主公 2026-08-08 拍板

## 1. 范围

主公 2026-08-08 拍板"readme 里内容重新整理一下, 有重复的有不完整、过时的, 有不准确的".

## 2. 删 (3 段重复)

| 段 | 原位置 | 备注 |
|----|--------|------|
| "Why KALLAX vs Claude Code?" 第二次重复 | line 50-87 | 跟 line 113-150 完全相同 |
| "安装" 第二次重复 | line 89-93 | 跟 line 26-30 完全相同 |
| "文档结构" 第二次重复 | line 95-109 | 跟 line 32-46 完全相同 |
| **5 Levels × 4 Roles Q18 决策矩阵** | line 154-168 | v3.0.0 era (跟 5-Level Verify 重复) |
| **4 Roles 段** | line 186-191 | v3.0.0 era 简短 |
| **30 命令速查** | line 195-207 | v3.0.0 era, 跟 v3.34.6 不符 |
| **§快速开始 基本工作流** | line 211-243 | v3.0.0 era `kallax ticket:create` 等 |
| **§架构 ASCII 图** | line 247-292 | v3.0.0 era, 跟 manifesto/01-top-design 重复 |
| **§目录结构** | line 296-328 | v3.0.0 era (rust/core/ engine/ cli/ server/ ticket-engine/) 跟实际不符 |
| **§配置 yaml** | line 332-368 | v3.0.0 era `version: "3.0.0"` |
| **§KPI 表** | line 372-383 | v3.0.0 vs v2.7.6, 跟 EPIC-205 跑批不一致 |
| **§集成测试 (v3.8.1 真相化)** | line 387-415 | v3.8.0 教训段, 跟 EPIC-069-D 重复 |
| **§6 Release 时间线** | line 418-445 | v3.0.0 → v3.7.0 era, 跟 CHANGELOG 重复 |

## 3. 修 (6 处不准确)

| 项 | 之前 | 之后 | 来源 |
|----|------|------|------|
| 总 EPIC 累计 | 24 | **30** (19 + 11 EPIC-203-213) | EPIC-213 累计 |
| CLAUDE.md size | "3.3KB" + "1.1KB" 互相矛盾 | **188 行** (≤ 200 OK) | EPIC-209 trim 实际验证 |
| Immutable scripts 数 | "5" | **6** (4 verify + 1 hook + 1 smoke retention) | EPIC-174 加 smoke retention |
| DEPRECATED 文件数 | 22 | **23** (ARCHITECTURE.md) | EPIC-206 + EPIC-209 |
| Manifesto 文件数 | "5 文件" | **6 文件** (含 00-elevator-pitch.md) | EPIC-213 |
| 测试 TC 总数 | 散乱多处 | **31 PASS** (8 + 17 + 6 docs-only EPIC 累计) | EPIC-204/205 |

## 4. 保留 (跟 v3.34.6 1:1)

- Why KALLAX? 段 (1 处不重复, 跟 EPIC-171 联合)
- Why KALLAX vs Claude Code? 段 (1 处, 5 维度对比 + 3 句使用判断 + Trigger Signals)
- 快速入口 7 个链接 (CLAUDE.md + 6 个 manifesto 文件)
- 安装 1 处 (跟 EPIC-160 install.sh 1:1)
- 文档结构 1 处 (跟 EPIC-197 SoT 归并 1:1)
- 累计统计 (新增, 跟 EPIC-205 跑批 1:1)
- 4-PR 工作流 + 5-Level Verify + 9 专家 + 4 北极星指标 (跟 EPIC-069-D/207/204/056-A 联合)
- 贡献 + 许可 + 致谢

## 5. 联动

- EPIC-206 (manifesto) — 5 文件 → 6 文件 (含 EPIC-213)
- EPIC-209 (retrospective) — CLAUDE.md 188 行 + _deprecated-index 23
- EPIC-212 (GitHub intro) — README top 跟本文 1:1 联合
- EPIC-213 (elevator pitch) — README 引用 00-elevator-pitch.md
- EPIC-205 (6 阶段跑批) — 累计统计 1:1
- EPIC-074 + EPIC-207 (4-PR + master review) — 4-PR 工作流段

## 6. 0 改 source code / 0 增 Rule / 0 增 immutable script

跟 EPIC-197/199/200/201/202-A/B/C docs-only EPIC 1:1 pattern.

## 7. 4-PR 流程 (本 EPIC-214, 严格 EPIC-207 v2)

| 阶段 | 操作 | 验证 |
|------|------|------|
| Step 1 | feature/EPIC-214-readme-reorg (worktree) | README.md 463 → 157 行 |
| Step 2 | PR-1: feature → testing | master review + comment |
| Step 3 | PR-2: testing → main | FF push + master review comment |
| Step 4 | PR-3: main → miao | 独立 PR + 主公亲自 review |

## 8. Reviewer

- 主公 (拍板"重新整理")
- master (执行)
- EPIC-212 (GitHub intro 源) + EPIC-213 (elevator pitch 源) + EPIC-206 (manifesto 源)