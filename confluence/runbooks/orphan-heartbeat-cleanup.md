# Runbook: Orphan Heartbeat Daemon Cleanup

> **EPIC-016-O** — `scripts/kallax-cleanup.sh` + `.kallax/hooks/session_start.sh` 集成清理
> **Author**: master_main (after A+B expert review)

## 现象

`heartbeat-daemon.sh` 是 KALLAX 实例的常驻心跳进程。预期 lifecycle:
1. `session_start.sh` 启动 daemon (`run_daemon`)
2. Daemon 每 60s 写 `state.json.heartbeat.last_beat`
3. `session_start.sh` 退出时，EXIT trap 杀自己的 daemon

实际会有 daemon 累积：
- 用户 Ctrl-C (SIGINT) 杀 session，但 daemon 不在 EXIT trap 范围 → orphan
- 系统断电 / kernel panic → daemon 死但 state.json 残留
- Performer 写错 daemon 启动逻辑 → 多 daemon 启动

## 清理机制（3 道防线）

### 1. session_start.sh 自动清理（启动时）
- 位置：`.kallax/hooks/session_start.sh:226-291`
- 触发：每次 session 启动
- 行为：扫描 `ps` 中所有 `heartbeat-daemon` pid，验证 `instance_dir` 不存在 + `etime > 1h` 才杀
- 防御：跨实例误杀（`pid_belongs_to_kallax()` 检查 cmdline 找 INSTANCE_ID）
- 时机：daemon 启动**前**（A 组 P1 修复）

### 2. scripts/kallax-cleanup.sh（手动 / cron）
- 位置：`scripts/kallax-cleanup.sh`
- 触发：用户手动跑，或 `cron` 定期
- 行为：默认 dry-run，加 `--force` 才真改
  - STALE state.json (last_beat > 5min) → 标 ZOMBIE
  - Orphan daemon (instance_dir missing + etime > 1h) → kill
- 对称语义（B 组 MEDIUM 修复）：无 `--force` = dry-run

### 3. .kallax/logs/orphan_kills.jsonl 审计
- 每次杀 orphan 写一行 JSON: `{ts, event, pid, etime, etime_sec, killer_instance}`
- 全局可读，所有 instance 都能审计
- B 组 observability 修复

## 怎么用

### 定期清理
```bash
# Dry-run (默认, 安全)
bash scripts/kallax-cleanup.sh

# 真杀 (需要 --force)
bash scripts/kallax-cleanup.sh --force
```

### 调查 orphan 来源
```bash
# 列出最近 10 次 orphan kill
tail -10 .kallax/logs/orphan_kills.jsonl | jq

# 统计哪个 instance 杀得最多
jq -r '.killer_instance' .kallax/logs/orphan_kills.jsonl | sort | uniq -c | sort -rn
```

### 紧急手动清理
```bash
# 列出所有 orphan (instance_dir 缺失的 daemon)
for pid in $(pgrep -f heartbeat-daemon); do
  cmdline=$(tr '\0' ' ' < /proc/$pid/cmdline 2>/dev/null)
  instance=$(echo "$cmdline" | awk '/heartbeat-daemon\.sh$/ {print $(NF-1)}')
  [ ! -d ".kallax/instances/$instance" ] && echo "ORPHAN $pid: $cmdline"
done

# 真杀
pkill -9 -f "heartbeat-daemon"  # 暴力, 慎用
```

## 阈值

| 阈值 | 值 | 理由 |
|---|---|---|
| Orphan etime | > 1h | 给活跃 daemon 留缓冲，避免误杀正在跑 30min 的 |
| STALE last_beat | > 5min | 60s 心跳 × 5 容忍，>5min 视为已死 |
| 启动延迟 (session_start) | 立即 | 用户每次启动都跑 |

## 已知限制

1. **macOS etime 解析**：依赖 `ps -o etime=` 输出格式
2. **跨平台 instance_dir 检查**：`/proc/<pid>/cmdline` (Linux) vs `ps -o command=` (macOS)
3. **race window**：session_start 期间 daemons 状态可能瞬间不一致

## Review History

| Date | Reviewer | Result |
|---|---|---|
| 2026-06-07 | A组 (Forward) | 5 AC partial (P0 instance check, P1 timing) |
| 2026-06-07 | B组 (Attack) | HIGH risk (cross-instance, macOS etime) |
| 2026-06-07 | master (fix) | 5 fixes applied: instance guard, etime_to_seconds, --force symmetric, audit log, timing |

## 相关 Tickets

- `EPIC-016-O` (本 ticket)
- `EPIC-016-M` (state.json Edit 防护) — 互补
- `EPIC-016-R` (session_start stdio + onboarding) — 同文件
- `EPIC-016-S` (Layer A 实施 + 回归修复) — 提升性能
