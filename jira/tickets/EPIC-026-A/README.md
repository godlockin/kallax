# EPIC-026-A: Bash hot path 6 并发 bug 修 (FIFO/SQLite race)

## 需求

P0 fixes 是 v1 全范围的前置, 估时 8h. 避免 session_start.sh 黑洞在 v1 实施期间复现

## 接受标准 (AC)

详见 `ticket.json`.

## 文件范围

- .kallax/hooks/session_start.sh
- scripts/heartbeat-daemon.sh
- scripts/lib/daemon.sh

## 依赖

无

## 预估工时

8 小时

## 状态

| 时间 | 状态 | 操作者 | 备注 |
|------|------|--------|------|
| 2026-06-07 | ready | master_main | 创建 (主公 4 决策批准) |
