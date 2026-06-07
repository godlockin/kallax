# EPIC-026-B: session_start.sh 黑洞风险防 (watchdog + fail-closed)

## 需求

黑洞重演的最强防御. watchdog 监控 + fail-closed safety check 双保险

## 接受标准 (AC)

详见 `ticket.json`.

## 文件范围

- .kallax/hooks/session_start.sh
- scripts/heartbeat-watchdog.sh
- scripts/lib/session-start-safety.sh

## 依赖

EPIC-026-A

## 预估工时

6 小时

## 状态

| 时间 | 状态 | 操作者 | 备注 |
|------|------|--------|------|
| 2026-06-07 | ready | master_main | 创建 (主公 4 决策批准) |
