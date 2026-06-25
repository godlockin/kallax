# EPIC-022-B: Pre-commit Hook + Conductor Scope Check

## 需求

Pre-commit hook 调用 authz/check.sh 强制 conductor scope check — 治根 BE-23 反复 (performer 越权写 miao 路径).

## 接受标准 (AC)

详见 `ticket.json` (12 项 L1-L4 + authz fail-closed).

## 文件范围

- `.git/hooks/pre-commit`
- `src/permissions/conductor-scope.ts`
- `src/permissions/authz-check.ts`
- `tests/integration/conductor-scope*.sh`

## 依赖

| 依赖 | 状态 | 备注 |
|------|------|------|
| EPIC-022-A | in_progress | 3 role definition 必须先完成 |
| BE-23 fix | done (commit 7347ae6) | pre-commit branch-aware action mapping |
| BE-25 | open | 可能需要 --no-verify 处理 hot path 边界 |

## 预估工时

- estimate_days: 3
- estimated_hours: 24

## 状态

| 时间 | 状态 | 操作者 | 备注 |
|------|------|--------|------|
| 2026-06-07 | blocked | master_main | Phase 0.1 拆分 (跟 EPIC-027-A 联合) |
| 2026-06-25 | blocked | performer-EPIC-027-A | Phase 0.1 tracking metadata 落地 (estimated_hours) |
