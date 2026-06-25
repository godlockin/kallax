# EPIC-022-C: Workspace Switch + Read-Only Path

## 需求

workspace-switcher.ts 支持 master/conductor/performer 切换, readonly-path.ts 标识 miao/.git/hooks/.kallax/config 为 readonly — 防 conductor 越权写 miao.

## 接受标准 (AC)

详见 `ticket.json` (13 项 L1-L4 + realpath 顺序在前 + 跨 workspace 审计).

## 文件范围

- `src/permissions/workspace-switcher.ts`
- `src/permissions/readonly-path.ts`
- `.kallax/state/state.json`
- `scripts/workspace/*.sh`
- `tests/integration/workspace-*.sh`

## 依赖

| 依赖 | 状态 | 备注 |
|------|------|------|
| EPIC-022-A | in_progress | 3 role definition 必须先完成 |

## 预估工时

- estimate_days: 4
- estimated_hours: 32

## 状态

| 时间 | 状态 | 操作者 | 备注 |
|------|------|--------|------|
| 2026-06-07 | blocked | master_main | Phase 0.1 拆分 (跟 EPIC-027-A 联合) |
| 2026-06-25 | blocked | performer-EPIC-027-A | Phase 0.1 tracking metadata 落地 (estimated_hours) |
