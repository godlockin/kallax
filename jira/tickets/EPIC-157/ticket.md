# EPIC-157 — Expert Binding Tracking

> **Master 建议 expert + Performer 实际 binding + Review 复盘一致率 + mis_dispatch_rate 北极星打通**

## 起源

主公 2026-08-02 review 当前框架能否"同类多实例并行"时拍板:

- Master 拆卡时给 `suggested_expert`
- Performer 领卡时 binding `actual_expert` + `expert_binding_at`
- 偏离时 `binding_change_reason` 必填 (治 silent 改 expert)
- 任务完成后通过 `phase-review` 复盘 + `sprint-metrics` 暴露 mis_dispatch_rate

## 4 新字段 (ticket.json)

| 字段 | 类型 | 必填时机 | 枚举 |
|---|---|---|---|
| `expert_binding.suggested_expert` | `string \| null` | Master 拆卡时 (建议) | 4 default + 5 extended + 15 local |
| `expert_binding.actual_expert` | `string` | Performer claim 时 (必填) | 同上 |
| `expert_binding.expert_binding_at` | `ISO8601 string` | Performer claim 时 (自动) | timestamp |
| `expert_binding.binding_change_reason` | `string` | 仅当 actual != suggested (必填非空) | free text |

## 跟现有 Rule 联合 (0 冲突)

| Rule | 关系 |
|---|---|
| BE-14 1 ticket 1 subagent 串行 | ✅ 不破 (metadata 不改派单模式) |
| EPIC-054-A worktree 隔离 | ✅ 不破 (字段在 ticket.json, 不动 git worktree) |
| EPIC-023-C mis_dispatch_rate 北极星 | ✅ **直接打通数据源** |
| EPIC-059-F 派遣 Checklist 11 项 | ✅ 可选加第 12 项 "expert binding 记录" |
| Rule 34 bugfix 独立复现 | ✅ 互补 (binding 字段 + reproduction_command 字段正交) |

## 历史 ticket 处理

- 仅新 ticket 强制 4 字段 (留空 = legacy-no-binding)
- sprint-metrics 计算 mis_dispatch_rate 时历史 ticket 跳过不计入分母
- validator 加载历史 ticket.json 不报错 (向后兼容)

## Acceptance (12 项, 跟 ticket.json AC 段同步)

AC1~AC12 见 `jira/tickets/EPIC-157/ticket.json` `acceptance` 字段.

## Scope

- **新增**: `node/src/schema/ticket-schema.ts` + `ticket-validator.ts` + 2 个测试文件
- **改**: `node/src/cli/commands/claim.ts` + `submit-pr.ts` + `scripts/metrics/lib/metrics.sh` + `docs/reference/slash-commands.md` + `CLAUDE.md`
- **不动**: existing ticket.json (历史兼容) + 4-branch flow + worktree 模式 + BE-14/EPIC-054-A/Rule 34

## 估时

~5 h (1 EPIC 周期), 含 5-Level Verify + 4-branch flow.