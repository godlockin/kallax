# EPIC-015-B: state.json Schema + Heartbeat 脚本

**Priority**: P0 | **Estimate**: 2d | **Status**: pending
**Assignee**: unassigned | **Branch**: feature/epic-015-b

## 背景
没有统一的 instance 状态 schema。heartbeat 字段全 null，无自动 tick 机制。团队状态不可见。

## 交付物

### 1.3 state.json Schema
- 路径: `.kallax/instances/<instance_id>/state.json`
- Schema 定义 (JSON):
```json
{
  "instance_id": "conductor_main",
  "role": "conductor",
  "pid": 12345,
  "status": "ACTIVE",
  "branch": "miao",
  "cwd": "/path/to/worktree",
  "created_at": "ISO8601",
  "heartbeat": {
    "interval_seconds": 60,
    "last_beat": "ISO8601",
    "missed_count": 0
  },
  "current_task": {
    "ticket_id": null,
    "worktree_path": null
  }
}
```
- 验收: `jq` 解析成功，所有字段完整

### 1.5 心跳自动 tick 脚本
- 路径: `scripts/heartbeat-daemon.sh`
- 功能:
  1. 读取当前 instance 的 state.json
  2. 每 60s 更新 `heartbeat.last_beat` 和 `heartbeat.missed_count`
  3. 后台运行，PID 记录到 state.json
  4. 父进程退出时自动清理 (trap EXIT)
- 路径: `scripts/check-stale.sh`
- 功能:
  1. 扫描所有 `.kallax/instances/*/state.json`
  2. missed_count >= 3 → status = STALE
  3. 输出 STALE instance 列表
- 约束: 纯 Bash + jq，不依赖 Node/Python

## 架构原则
- 治理层维护心跳，智能层读取心跳做决策
- 心跳脚本是后台 daemon，不受 LLM session 生命周期影响
- Stale 检测由 cron 或 Conductor 定期触发

## 验收标准
- [ ] state.json schema 文档化
- [ ] heartbeat-daemon.sh 后台运行，60s tick 正常
- [ ] check-stale.sh 正确检测 missed >= 3 的 instance
- [ ] 父进程退出 → daemon 自动清理
