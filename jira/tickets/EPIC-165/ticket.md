# EPIC-165 — Showcase catalog + 英文 README 国际化

> **借鉴 loopx 7 真实轨迹 showcase + 中英双语 README (24KB EN + 24KB CN)**

## 起源

主公 2026-08-05 review loopx README + showcase catalog 后拍板:

- **P1 高 ROI**: KALLAX 缺对外叙事层 (showcase + i18n)
- 产品经理报告: "kallax 完全没有 use-case 叙事 / 全是 internal 规则/脚本 / 无法对外展示价值"
- 详细分析: `confluence/decisions/loopx-vs-kallax-product-gap-2026-08-05.md`

## loopx showcase 模式 (借鉴)

| 维度 | loopx | KALLAX (现状) | 差距 |
|------|-------|---------------|------|
| Showcase catalog | `docs/showcases/README.md` + json | 无 | **大** |
| 真实 case 数量 | 7 个 (0617/0619/0623/0624/0627/0620) | 无 | **大** |
| case 质量 | 可复现证据 + 模式归类 | 无 | **大** |
| 英文 README | 24KB | 无 (仅 17.8KB 中文) | **大** |
| i18n 索引 | 双语 README + 中英对照 | 无 | 中 |

## 设计 (3 步)

1. **Showcase catalog** — `docs/showcases/` + json schema 1:1 复用 loopx
2. **≥7 showcase case** — 从现有 EPIC trace 生成 (069-D/152/155/157/158/160/161)
3. **英文 README + i18n 索引** — `README.en.md` + `docs/i18n/README.md`

## showcase case 选型 (7 个, 从现有 governance trace)

| EPIC | showcase 标题 | 模式 |
|------|--------------|------|
| EPIC-069-D | check-claim-evidence 防止假 PASS | fact-forcing |
| EPIC-152 | Rule 34 bugfix 独立复现 | canary chain |
| EPIC-155 | 4-branch bypass 历史债备案 + 追溯 | retro remediation |
| EPIC-157 | expert binding 4 字段打通 mis_dispatch 北极星 | metric wiring |
| EPIC-158 | sqlite skipIf 治根 CI debt | debt cleanup |
| EPIC-160 | install.sh Omnibus 95 files deploy | framework distribution |
| EPIC-161 | retrospective-routine.sh 6 阶段 routine | periodic review |

## 跟现有 EPIC 联合 (0 冲突)

| EPIC | 关系 |
|------|------|
| BE-14 1 ticket 1 subagent 串行 | ✅ 不破 |
| EPIC-054-A worktree 隔离 | ✅ 不破 |
| EPIC-157 binding tracker | ✅ showcase 数据源 |
| EPIC-159 CLAUDE.md trim | ✅ 互补 |
| EPIC-160 install Omnibus | ✅ 互补, 国际化基础 |
| Rule 34 bugfix 独立复现 | ✅ 互补, showcase 用 |

## Acceptance (10 项)

AC1~AC10 见 `jira/tickets/EPIC-165/ticket.json` `acceptance` 字段.

## Scope

- **新增**: 1 showcase catalog + 7 case + 1 json + 1 英文 README + 1 i18n 索引 + 1 test
- **改**: `CLAUDE.md`
- **不动**: 现有 source code + Rule + BE-14/EPIC-054-A

## 估时

~12 h (1 EPIC 周期), 含 5-Level Verify + 4-branch flow.

## Phase

PHASE-019 — LoopX Borrow (2026-08-05 主公拍板)