# EPIC-022-E: Integration Tests + 5-Expert A+B Review

## 需求

permission-v1-e2e.sh 端到端 test (task:claim → worktree → commit → merge), role-matrix.json 6 role × 10 action 矩阵, 5-expert A+B review 准备.

## 接受标准 (AC)

详见 `ticket.json` (13 项 L1-L4 + 5-expert review 准备 + LESSONS-LEARNED.md).

## 文件范围

- `tests/integration/permission-v1-e2e.sh`
- `tests/integration/role-matrix.json`
- `EPIC-022-LESSONS-LEARNED.md`

## 依赖

| 依赖 | 状态 | 备注 |
|------|------|------|
| EPIC-022-A | in_progress | 3 role definition |
| EPIC-022-B | blocked | pre-commit + conductor scope |
| EPIC-022-C | blocked | workspace switch + readonly |
| EPIC-022-D | blocked | role transition |

> 4/4 upstream blocked → E 无法启动, 派单时机 = 4/4 done

## 预估工时

- estimate_days: 5
- estimated_hours: 40

## 状态

| 时间 | 状态 | 操作者 | 备注 |
|------|------|--------|------|
| 2026-06-07 | blocked | master_main | Phase 0.1 拆分 (跟 EPIC-027-A 联合) |
| 2026-06-25 | blocked | performer-EPIC-027-A | Phase 0.1 tracking metadata 落地 (estimated_hours) |
