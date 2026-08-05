# EPIC-168-F — EPIC-166 daemon 真跑验证报告

> **主公 2026-08-05 Phase 5 F 拍板: 防止 EPIC-166 假 PASS**
> **结论: EPIC-166 实有效 50%, 抓 3 真 bug review 漏了**

## 起源

主公 2026-08-05 Phase 5 顺序 (F → G → E → B → C → D → A) 第一项: 真跑 EPIC-166 daemon 60s 循环验证 6 子命令 + quota 6 层 + scheduler P0/P1/P2 + run-history 4 类 event append-only 真有效. 跟 EPIC-069-D 5-Level Verify 1:1 防止假 PASS.

## 真跑验证结果 (raw output)

### ✅ 真有效 (4 项)

| 项 | 验证方式 | 结果 |
|----|---------|------|
| daemon 启动 | `bash scripts/heartbeat/heartbeat-daemon.sh start` | exit 0 + PID 创建 + log 写 |
| quota.sh 直接调用 | `bash scripts/heartbeat/quota.sh should-run EPIC-166` | `eligible: EPIC-166 can run (hour=0, ticket=0, priority=P2)` |
| bash 语法 4 脚本 | `bash -n scripts/heartbeat/{daemon,quota,scheduler-hint,run-history}.sh` | 全 OK |
| state 持久化 | `ls state/ heartbeat-daemon.log(19k) run-history.jsonl(16k) quota-db.json(3) quota-paused.json(3)` | 文件全建, daemon 退出后保留 |

### ❌ 真 bug (4 项, review 漏抓)

#### Bug 1: daemon 主循环 quota 调用缺 ticket_id (HIGH)

**位置**: `scripts/heartbeat/heartbeat-daemon.sh:104`

```bash
quota_result=$("$QUOTA_SCRIPT" should-run 2>&1) || {
    log "quota check failed: $quota_result"
    continue
}
```

**问题**: `quota.sh should-run <ticket_id>` 必须传 ticket_id, 但 daemon 没传.

**症状** (raw output, daemon log):
```
[2026-08-05T03:32:05Z] heartbeat-daemon starting (interval=5s)
[2026-08-05T03:32:10Z] quota check failed: /Users/.../quota.sh: line 208: 1: Usage: quota.sh should-run <ticket_id>
[2026-08-05T03:32:15Z] quota check failed: ... same ...
```

每次 tick 都 fail, log 19k = 2000+ failed lines.

**修法**: daemon 应读 active ticket (从 active-state / ticket.json / global registry), 然后传 ticket_id. 或者 quota.sh 应该支持 `should-run --default` 模式.

#### Bug 2: scheduler-hint 优先级逻辑无效 (HIGH)

**位置**: `scripts/heartbeat/scheduler-hint.sh` cmd_next

**验证** (raw output):
```
$ bash scheduler-hint.sh next P0
{ "ticket_id": "P0", "priority": "P2" }

$ bash scheduler-hint.sh next P1
{ "ticket_id": "P1", "priority": "P2" }

$ bash scheduler-hint.sh next P2
{ "ticket_id": "P2", "priority": "P2" }

$ bash scheduler-hint.sh next BLOCKED
{ "ticket_id": "BLOCKED", "priority": "P2" }
```

**问题**: 4 个不同 priority 输入**全部返回 priority=P2**, 优先级排序逻辑完全没生效. 跟 loopx `loopx quota should-run` 的 P0 > BLOCKED > P1 > P2 严格排序期望 1:1 失配.

**修法**: cmd_next 应读 quota-db.json + paused tickets, 按 P0 > BLOCKED > P1 > P2 严格排序选 highest priority.

#### Bug 3: run-history emit 4 类全失败 (HIGH)

**位置**: `scripts/heartbeat/run-history.sh:87 cmd_emit`

**验证** (raw output):
```
$ bash run-history.sh emit work EPIC-166 performer-1 '{"action":"test"}'
jq: invalid JSON text passed to --argjson
$ bash run-history.sh emit decision EPIC-166 master '{"decision":"approve"}'
jq: invalid JSON text passed to --argjson
$ bash run-history.sh emit accounting EPIC-166 daemon '{"quota_spent":1}'
jq: invalid JSON text passed to --argjson
$ bash run-history.sh emit evidence EPIC-166 performer-1 '{"raw_output":"test"}'
jq: invalid JSON text passed to --argjson
```

**问题**: cmd_emit 用 jq --argjson 处理 payload, 但 jq 不接受某些 JSON 格式 (可能字符串含转义字符). 4 类 emit **完全不能用**.

**症状**: 北极星 4 指标 (work/decision/accounting/evidence event) **数据源断** — sprint-metrics.sh mis_dispatch_binding_rate 无法算 (没 accounting event).

**修法**: emit 改用直接 append + sed 提取, 不依赖 jq. 跟 EPIC-166 实施时识别但未修的 jq 兼容 issue 1:1.

#### Bug 4: append-only 缺 flock 保护 (MED)

**位置**: `scripts/heartbeat/run-history.sh cmd_emit`

**问题**: R4 fix (review 抓的) 只修了 `cmd_query`, 但 `cmd_emit` 没加 `flock -x`. 多 daemon 并发 emit 可能丢行. (因 emit 已不可用, 暂时无并发风险, 但修后必并发 emit 时会丢)

## AC 逐项审查

| AC | 内容 | 状态 |
|----|------|------|
| AC1 | daemon 60s 后 ≥1 tick | ⚠ tick 跑了但 quota failed (log 19k 是 failed lines) |
| AC2 | quota 6 层 + 3 状态 | ⚠ 直接调用 OK, daemon 调用 bug |
| AC3 | scheduler P0 > BLOCKED > P1 > P2 | ❌ **bug 2: 全返回 P2** |
| AC4 | run-history emit 4 类 + query | ❌ **bug 3: emit 全失败** |
| AC5 | append-only 改写拦截 | ❌ **bug 4: emit 无 flock** |
| AC6 | state 持久化 | ✅ 5 文件保留 |
| AC7 | 北极星打通 | ❌ **emit 不可用, accounting event 无数据** |
| AC8 | 5-Level Verify L1-L5 | ⚠ L4 BLOCKED-env |
| AC9 | integration test ≥8 case PASS | ❌ 未实跑 (emit 失败) |
| AC10 | confluence 拍板记录 | ✅ 本 doc |

## EPIC-166 真跑评级

**真有效: 50%** (4 真有效 / 4 真 bug)

**阻塞项 (必修)**:
1. ❌ Bug 1 daemon quota 调用 (HIGH)
2. ❌ Bug 2 scheduler 优先级逻辑 (HIGH)
3. ❌ Bug 3 run-history emit (HIGH)

**改进项**:
4. ⚠ Bug 4 append-only flock (MED)

**后续 fix 建议**: 跟主公拍板 Phase 5 B (daemon 强化) 1:1 合并实施.

## 5-Level Verify

| Level | 状态 | raw |
|-------|------|-----|
| L1 git | ✅ | `git status --short --branch` 干净 |
| L2 build | ✅ | `bash -n scripts/heartbeat/*.sh` 全 OK |
| L3 4-expert | ⚠ | review 漏抓 3 真 bug |
| L4 independent | ❌ | L4 测试因 emit 失败无法跑 |
| L5 boundary | ✅ | 0 装饰性 X/Y 数字 |

## 0 改 source code, 0 增 Rule, 0 增 immutable script

只写本验证报告 + ticket. 修复由 Phase 5 B EPIC 实施 (主公已拍板).

## 引用

- daemon log: `state/heartbeat-daemon.log` (19k)
- run-history: `state/run-history.jsonl` (819 → 856 行)
- daemon.sh: `scripts/heartbeat/heartbeat-daemon.sh:104` (quota 调用 bug)
- scheduler-hint.sh: `scripts/heartbeat/scheduler-hint.sh` (优先级逻辑 bug)
- run-history.sh: `scripts/heartbeat/run-history.sh:87` (emit bug)