# EPIC-164 — Self-Repair Skill

> **借鉴 loopx `skills/loopx-self-repair/SKILL.md` (5 步 repair loop + dream-up 机制)**

## 起源

主公 2026-08-05 review loopx 后拍板:

- **P1 中 ROI**: KALLAX 缺 Self-Repair skill
- 治理审计员报告: "KALLAX 无 self-repair skill / check-self-heal.sh 仅检查 self-heal pattern / retrospective-routine.sh 是阶段性回顾, 非运行时自修复"
- 详细分析: `confluence/decisions/loopx-vs-kallax-skill-gap-2026-08-05.md`

## loopx self-repair 模式 (借鉴)

| 维度 | loopx | KALLAX (现状) | 差距 |
|------|-------|---------------|------|
| 独立 skill | `skills/loopx-self-repair/SKILL.md` | 无 | **大** |
| 5 步 repair loop | pause → evidence → classify → assign → repair | 无 | **大** |
| dream-up 机制 | 重复错误视为 product gap, 更新 skill/docs/smoke | 无 | **大** |
| evidence discipline | 不读 raw private logs / 不 solve contradictory by guessing | 无 | 中 |
| vision writeback | 写回 active state | 无 | 中 |

## 设计 (5 步 repair loop)

1. **Pause delivery** — 不继续 quota / adapter work
2. **Build evidence packet** — structured surfaces (status / diagnose / quota should-run / history)
3. **Classify failure** — 5 类: agent mistake / state projection bug / active-state authoring gap / benchmark harness mismatch / docs process hygiene
4. **Assign responsible layer** — 治根 (lowest durable layer)
5. **Repair** — write back correct state / fix CLI projection / update docs

## 跟现有 EPIC 联合 (0 冲突)

| EPIC | 关系 |
|------|------|
| BE-14 1 ticket 1 subagent 串行 | ✅ 不破 |
| EPIC-054-A worktree 隔离 | ✅ 不破 |
| EPIC-161 retrospective-routine | ✅ **互补** (阶段性回顾 vs 运行时自修复) |
| EPIC-160 install.sh Omnibus | ✅ 集成 (install 阶段) |
| EPIC-162 skill 插件化 | ✅ 1:1 pattern (skill + scope + agents) |
| Rule 34 bugfix 独立复现 | ✅ 互补 |

## Acceptance (13 项)

AC1~AC13 见 `jira/tickets/EPIC-164/ticket.json` `acceptance` 字段.

## Scope

- **新增**: 1 skill 包 (SKILL.md + scope + agents/) + 1 test + 1 docs/reference
- **改**: `scripts/install.sh` + `CLAUDE.md`
- **不动**: 现有 source code + Rule + BE-14/EPIC-054-A

## 估时

~8 h (1 EPIC 周期), 含 5-Level Verify + 4-branch flow.

## Phase

PHASE-019 — LoopX Borrow (2026-08-05 主公拍板)