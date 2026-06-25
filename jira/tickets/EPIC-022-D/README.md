# EPIC-022-D: Role Transition (master/conductor/performer)

## 需求

role-transition.ts 实现 master/conductor/performer 状态机, break-glass ≤ 1h TTL + 全 audit. session_start.sh 启动时验证 role.

## 接受标准 (AC)

详见 `ticket.json` (13 项 L1-L4 + 循环继承检测 + break-glass TTL).

## 文件范围

- `src/permissions/role-transition.ts`
- `scripts/role-transition.sh`
- `.kallax/hooks/session_start.sh`
- `tests/integration/role-transition*.sh`

## 依赖

| 依赖 | 状态 | 备注 |
|------|------|------|
| EPIC-022-A | in_progress | 3 role definition 必须先完成 |

## 预估工时

- estimate_days: 3
- estimated_hours: 24

## 状态

| 时间 | 状态 | 操作者 | 备注 |
|------|------|--------|------|
| 2026-06-07 | blocked | master_main | Phase 0.1 拆分 (跟 EPIC-027-A 联合) |
| 2026-06-25 | blocked | performer-EPIC-027-A | Phase 0.1 tracking metadata 落地 (estimated_hours) |
