# EPIC-021-F: expert_invocations 降级链 (Redis→SQLite→file)

## 需求

实现 expert_invocations 写入降级链, 给 KALLAX 北极星指标 (Product 共识 P0) 提供数据源. 复用已有 heartbeat + state.json, 不引入新基础设施.

## 接受标准 (AC)

详见 `ticket.json`. 10 条 AC.

## 降级链架构

```
       ┌─────────────────────────┐
emit → │ scripts/lib/queue.sh    │
       │   backend=auto          │
       └────────────┬────────────┘
                    │ probe
        ┌───────────┼───────────┐
        ▼           ▼           ▼
   ┌─────────┐ ┌─────────┐ ┌─────────┐
   │ Redis   │ │ SQLite  │ │ JSONL   │
   │ Stream  │ │ table   │ │ file    │
   │ (主)    │ │ (落盘)  │ │ (兜底)  │
   └────┬────┘ └────┬────┘ └────┬────┘
        └───────────┴───────────┘
              health probe 每 5 min
              自动回切到 Redis
```

## 3 个函数 (脚本 lib)

```bash
# scripts/lib/expert-invocation-queue.sh

# emit: 写一条 invocation
# $1: expert_id (e.g. kallax.backend.001)
# $2: ticket_id (e.g. EPIC-016-B)
# $3: timestamp (optional, default now)
emit() {
  local expert_id="$1"
  local ticket_id="$2"
  local ts="${3:-$(date +%s)}"
  local payload="{\"expert_id\":\"$expert_id\",\"ticket_id\":\"$ticket_id\",\"ts\":$ts}"
  
  # 探测当前 backend
  local backend=$(get_backend)
  
  case "$backend" in
    redis)
      redis-cli -x XADD expert_invocations '*' payload "$payload" 2>/dev/null || {
        echo "WARN: Redis down, falling back to SQLite" >&2
        set_backend sqlite
        sqlite_emit "$payload"
      }
      ;;
    sqlite)
      sqlite_emit "$payload" 2>/dev/null || {
        echo "WARN: SQLite down, falling back to file" >&2
        set_backend file
        file_emit "$payload"
      }
      ;;
    file)
      file_emit "$payload"
      ;;
  esac
}

# drain: 读 + 清空
drain() {
  local backend=$(get_backend)
  case "$backend" in
    redis) redis-cli XRANGE expert_invocations - + ;;
    sqlite) sqlite3 .kallax/state/expert_invocations.db "SELECT * FROM invocations" ;;
    file) cat .kallax/queue/expert_invocations.jsonl ;;
  esac
}

# health: 报告
health() {
  cat <<EOF
{
  "backend": "$(get_backend)",
  "latency_ms": $(probe_latency),
  "queue_size": $(queue_size),
  "last_error": "$(get_last_error)"
}
EOF
}
```

## state.json 扩展

```json
{
  "instance_id": "master_...",
  "role": "master",
  "expert_invocations": [
    {
      "expert_id": "kallax.architect.001",
      "ticket_id": "EPIC-016-D",
      "ts": 1700000000,
      "backend": "redis"
    }
  ]
}
```

LRU 1000 条: 超出后最旧的刷到 `.kallax/state/expert_invocations.archive.jsonl`, 不丢数据.

## 降级触发条件

| 触发 | 动作 | 重试 |
|---|---|---|
| Redis ping > 1s | 切 SQLite | 5 min 后试 Redis |
| SQLite write > 500ms | 切 file | 5 min 后试 SQLite |
| SQLite ENOSPC | 切 file | 5 min 后试 SQLite |
| File write 失败 | 报警 (master inbox) | 1 min 后试 file |
| Redis/SQLite/file 全失败 | 写 state.json fallback | 持续 retry |

## heartbeat-daemon.sh 集成

```bash
# scripts/heartbeat-daemon.sh 每 60s 跑
source scripts/lib/expert-invocation-queue.sh

# 1. 写自己的心跳
write_heartbeat

# 2. emit 一条 invocation (如果本轮有 ticket 进展)
if [ -n "$LAST_TICKET" ]; then
  emit "$MY_EXPERT_ID" "$LAST_TICKET" "$(date +%s)"
fi

# 3. 每 5 min 试回 Redis
if [ $((SECONDS % 300)) -eq 0 ]; then
  try_redis_recovery
fi
```

## 文件范围

4 个文件 (1 改, 3 新):
- `.kallax/state/state.json` (改: 加 expert_invocations 数组)
- `scripts/heartbeat-daemon.sh` (改: 集成 emit)
- `scripts/lib/expert-invocation-queue.sh` (新: 3 函数)
- `.kallax/queue/expert_invocations.jsonl` (新: 兜底文件, 初始空)

## ⚠️ 阻塞说明

无. F 独立, 可跟 A 并行.

## 预估工时

1.5 小时 (脚本 0.8h + 集成 0.3h + 测试 0.4h)

## 2-Group review 期望

- **A 组 (Forward)**: 校验 3 函数签名, 跑通 happy path (Redis up)
- **B 组 (Attack)**: 模拟 Redis/SQLite 全 down, 验证兜底 file 写入; 模拟 ENOSPC, 验证降级; 找 race condition (emit + drain 并发)

## 状态变更历史

| 时间 | 状态 | 操作者 | 备注 |
|------|------|--------|------|
| 2026-06-07 17:00 UTC | ready | master_main | 创建 |
