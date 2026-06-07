# EPIC-016-O: Stale heartbeat daemon 清理 — 防止累积

## 需求

当前 `.kallax/instances/` 堆积 38+ 个 conductor 实例（多数 zombie）。session_start.sh 启动新 daemon 时扫描并杀孤儿。

## 接受标准 (AC)

详见 `ticket.json`。4 条 AC：
1. session_start.sh 启动新 daemon 前，扫描 ps 所有 heartbeat-daemon.sh 进程
2. 杀 `started_at > 1h` 且 instance 不在 INSTANCES_DIR/ 的孤儿
3. 或写 `scripts/kallax-cleanup.sh` 一键清理
4. 默认安全：只杀 STALE 状态的 daemon，ACTIVE 的不动

## 技术要点

- `ps -eo pid,etime,command | grep heartbeat-daemon`
- 用 instance_id 匹配 INSTANCES_DIR 里的目录
- > 1h 阈值（防误杀刚启动的）
- 默认 dry-run 模式：`kallax cleanup --dry-run`

## 测试计划

- [ ] 模拟 1 个 daemon 进程，started_at 2h，instance 不存在 → 被杀
- [ ] ACTIVE instance 的 daemon 进程 → 不动
- [ ] cleanup --dry-run 模式不杀任何进程

## 依赖

无（但与 EPIC-016-R 协同最好，R 提供 daemon PID 跟踪，O 用它做杀孤儿判定）

## 文件范围

- `.kallax/hooks/session_start.sh` (update)
- `scripts/kallax-cleanup.sh` (new)

## ⚠️ 阻塞说明

file_scope 与 **EPIC-016-R** (session_start.sh) 重叠，**必须等 R 合并**才能开始。

## 预估工时

1.5 小时

## 状态变更历史

| 时间 | 状态 | 操作者 | 备注 |
|------|------|--------|------|
| 2026-06-06 05:55 UTC | ready | master_main | 创建 |
| 2026-06-06 15:30 UTC | backlog | master_main | 降级 backlog（等 R 释放 session_start.sh）|
