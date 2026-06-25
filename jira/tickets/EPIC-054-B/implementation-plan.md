# EPIC-054-B Implementation Plan

> instance 目录 LRU + 7 天 TTL 自动清理 (跟 Resource Management 硬要求一致, 治 A7)
> P1 | 6h | branch: feature/EPIC-054-B-instance-ttl
> Performer: performer-EPIC-054-B | base SHA: 7f88823

---

## 1. 目标 (跟 AC 1:1 对齐)

实现 instance 目录的 LRU + 7 天 TTL 自动清理机制 — 跟 Resource Management (KALLAX AGENTS.md §"Cache TTL Requirement") 硬要求一致. 治 A7 instance 僵尸 (88 instance 95% 僵尸 = 无 TTL).

| AC | 描述 | 验证方法 |
|----|------|----------|
| AC1 | 88 instance 目录 → 95% 清理后 ≤5 活跃 | 跑 `cleanup.sh --dry-run` 比对 active/zombie |
| AC2 | `scripts/instance/cleanup.sh` 实现 — LRU + 7 天 TTL | TDD 5 case |
| AC3 | `node/src/core/instance-registry.ts` 升级 — `lastHeartbeat` 超 7 天自动 unregister | 单元级 + integration |
| AC4 | `scripts/hooks/instance-ttl.sh` hook — session 启动时触发 | 文件存在 + 可执行 + 接口签名 |
| AC5 | `tests/integration/instance-ttl-test.sh` 5/5 PASS | 跑测试 |
| AC6 | A7 治根 — 88 → ≤5 (95% 清理) | mock 88 instance 验证清理率 |
| AC7 | Rule 9 KPI X/Y 精确 — 5/5 = 100.0% | 测试报告精确数字 |

---

## 2. 设计 (跟 Resource Management + EPIC-053-A 一致)

### 2.1 核心语义

```
Instance 生命周期:
  register → heartbeat → (TTL 7 天无心跳) → 自动清理

判定规则 (跟 .kallax/instances/{role}_{host}_{pid}/state.json schema 联动):
  - 优先读 .heartbeat.last_beat (legacy)
  - 降级读 .heartbeat.last_heartbeat (新 schema)
  - 再次降级读 .last_beat / .last_heartbeat (直接顶层)
  - 再降级读 .started_at / .created_at (注册时间兜底)
  - 若全部缺失 → 视为僵尸, 立即清理

清理决策:
  - last_beat > 7 天前 → 清理 (或归档, Master ticket 决定)
  - 保留: role ∈ {conductor, master} 且 last_beat ≤ 7 天 (活跃)
```

### 2.2 接口

```bash
# scripts/instance/cleanup.sh
# Usage: cleanup.sh [--dry-run] [--ttl-days=7] [--instances-dir=...]
# Exit 0: 清理完成 (含 0 清理)
# Exit 1: 参数错误
# Output: JSON 清理报告 (.kallax/logs/instance-cleanup-YYYYMMDD.json)

# scripts/hooks/instance-ttl.sh
# Session 启动 hook: 调 cleanup.sh --dry-run 输出日志
# 任何 session 启动时调用, 不阻塞, 只日志

# node/src/core/instance-registry.ts
# markInstancesStale(thresholdMs) — LRU 排序, 超 threshold unregister
# 升级: register 时若发现同 instance_id 已存在且超 TTL, 自动 unregister 老实例
```

### 2.3 与 Resource Management 一致

```typescript
// 跟 AGENTS.md §"Cache TTL Requirement" 联合
const instanceCache: Cache<string, Instance> = createCache('instance-registry', {
  max: 100,
  ttlMs: 7 * 24 * 60 * 60 * 1000,  // 7 天 (was 30 秒)
  updateAgeOnGet: true,
  dispose: (value, key) => {
    logger.info({ key }, 'instance cache entry disposed (7d TTL)');
  }
});
```

### 2.4 与 EPIC-053-A 一致

EPIC-053-A 实现了 L3↔L4 一致性检查, 本 ticket 复用其模式:
- TDD 5 case 显式覆盖
- Truth table 显式编码 (instance active/stale × TTL × LRU 位置)
- preflight 联动 (复用 `check-fact-forcing-preflight.sh`)

---

## 3. 步骤 (15 步中我的子集)

| Step | 动作 | 状态 |
|------|------|------|
| 1 | 拆 worktree (Master 已建, 我验证) | ✓ |
| 2 | 加载 ticket 描述 | ✓ |
| 3 | 加载 backend expert (instance-registry.ts + cache-layer.ts 已有) | ✓ |
| 4 | 深度分析 (88 dirs / 71 state.json / 95% 僵尸) | ✓ |
| 5 | 写本 plan | 写入中 |
| 6 | TDD 写测试 5 case (88 mock + LRU + TTL boundary + active 保留 + 清理日志) | 待执行 |
| 7 | 写实现 (cleanup.sh + instance-registry.ts 升级 + instance-ttl.sh hook) | 待执行 |
| 8 | 跑测试 5/5 PASS | 待执行 |
| 9-10 | A/B review (Conductor 责任) | 跳过 |
| 11 | 写 LESSONS-LEARNED.md | 待执行 |
| 12 | 报 PASS (outbox/pass-report-EPIC-054-B.json) | 待执行 |
| 13-15 | Master 强验证 / merge | 跳过 |

---

## 4. 文件清单 (跟 file_scope 1:1)

**创建** (5):
- `scripts/instance/cleanup.sh` — 核心 LRU + 7 天 TTL 清理
- `scripts/hooks/instance-ttl.sh` — hook 触发
- `tests/integration/instance-ttl-test.sh` — TDD 5 case
- `jira/tickets/EPIC-054-B/IMPLEMENTATION-PLAN.md` — 本文件
- `jira/tickets/EPIC-054-B/LESSONS-LEARNED.md` — 教训沉淀

**修改** (1):
- `node/src/core/instance-registry.ts` — 升级 TTL 30s → 7d, register 时检查 lastHeartbeat, 新增 `markInstancesByTTL()` 函数

**不动** (边界):
- `.kallax/instances/*` 现有目录 (实际清理由 Master 后执行, 不在本 ticket 范围)
- `.kallax/state/*` (跟 EPIC-054-C 联动)
- 其他 EPIC ticket

---

## 5. 测试设计 (AC5 5 case)

| Case | 描述 | 期望 |
|------|------|------|
| TC1 | 88 mock instance (5 活跃 + 83 僵尸, 时间戳分布 0-30 天前) | cleanup 报告 ≥80 清理 (≥95%), ≤5 保留 |
| TC2 | LRU 排序 (按 last_heartbeat 升序) | 排序结果: 最早心跳在前, 边界值正确 |
| TC3 | 7 天 TTL 边界 (last_beat = 6 天 23 时 / 7 天 / 7 天 1 时) | 6d23h 保留, 7d1h 清理, 7d 边界含 (≤7d 保留) |
| TC4 | 活跃 instance 保留 (role=conductor_77704, last_beat < 7d) | 不被清理, 仍在保留列表 |
| TC5 | 清理日志 (跟 audit 联动 — 写 .kallax/logs/instance-cleanup-YYYYMMDD.json) | 文件存在, JSON 含 total/cleaned/retained/lists |

**子检查**: AC7 — 5/5 = 100.0% (精确 X/Y, no estimate).

---

## 6. 风险 + 反模式 (跟 Rule 18 联合)

| 风险 | 缓解 |
|------|------|
| 误删活跃 instance | 三层保护: (1) 7 天 TTL 阈值 (2) 活跃 role 保留白名单 (3) dry-run 模式默认开启 |
| 跨 schema 不兼容 (legacy vs new heartbeat field) | 5 层 fallback: .heartbeat.last_beat → .heartbeat.last_heartbeat → .last_beat → .last_heartbeat → .started_at → 视为僵尸 |
| boundary 越界 (实际清理现有 instance) | 本 ticket 只交付机制, 实际清理由 Master 后执行 (写 outbox/pass-report 明确标 boundary_violations=0) |
| KPI falsification 反复 | commit message + 测试报告用 X/Y 精确格式 (5/5 = 100.0%) |
| 自审 | A/B review 跳过 (本 ticket 范围内不在 Performer 责任) |
| 跑测试不报 PASS | pass-report 含 raw test_output (raw stdout from bash test runner) |

---

## 7. LRU + TTL 设计说明

**TTL 设计**: 7 天 = 604,800,000 ms

**理由**:
- AGENTS.md §"Resource Management" 明确要求所有 cache 必须有 TTL
- 7 天覆盖典型周末 + 短假, 平衡"及时清理僵尸" vs "误删活跃 session"
- conductor/master session 启动后会持续心跳 (heartbeat interval 60s), 7 天无心跳 = 真正僵尸

**LRU 排序设计**:
- 按 last_heartbeat 升序, 最久没心跳在前
- 清理时优先清最久没心跳的 (LRU 语义)
- 若 instance 总数 ≤ max (100), 不触发清理 (LRU cache max=100 兜底)

**保留白名单**:
- role ∈ {conductor, master} (主公/调度员, 不轻易清)
- last_heartbeat ≤ 7 天
- 满足任一即可保留 (OR 语义)

**清理动作**:
- 默认 dry-run (打印会清什么, 不实际清)
- Master 后执行时改用 `--apply` 真正归档到 `.kallax/instances/.archive/`
- 不直接 `rm -rf` (EPIC-016-R 教训: 先归档再删)
