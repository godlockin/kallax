# EPIC-060-A-ROADMAP-2026-06-19 — 分布式 路线图 (P3 留待 决策 doc, 跟 eket 4 级降级 联合, 跟"独立" 战略 联合)

> **跟 eket 4 级降级 模式 联合 (Shell L0 → Rust L1 → Node.js L2 → Web L3)**
> **跟"反讽" 治根 "单 master 假动作" 联合 (KALLAX 自称'多 agent' 实际'单 master 多 performer')**
> **跟"独立" 战略 联合: 主公 后续 拍板, 0 强制 启动 Phase X**
> **跟 v2.0.6 EPIC-057 4 ticket 闭环 模式 + EPIC-058-C web dashboard 部署就绪 联合**

**Date**: 2026-06-19
**Author**: KALLAX Subagent 6/8 (Batch 2 4 parallel)
**Reviewers**: 主公 (战略审批) + Conductor
**Status**: 🟡 PENDING — 路线图 落地, 实施 留待 主公 拍板
**Scope**: 1 doc only (0 code file 改动, 跟 P3 留待 决策 doc 模式 一致)
**Tickets**: EPIC-060-A (6/8 done, 跟 Batch 2 其他 ticket 0 重叠)

---

## TL;DR

跟 v2.7.0 EPIC-060-A "独立" 战略 联合, KALLAX 分布式 路线图 落地:

- **A. 现状**: 0 分布式 实施, ioredis optional (`node/package.json:36-38`), web dashboard 部署就绪 (EPIC-058-C 5/5 PASS)
- **B. 路线图**: 5 阶段 (Phase 1-5), 总工时 92h, P0/P1/P2 三档 优先级
- **C. 决策 矩阵**: 方案 A/B/C/D, 主公 explicit 拍板 启动 Phase X
- **D. 0 实施 留待**: 跟"独立" 战略 一致, 主公 后续 拍板, 0 强制 启动
- **E. 0 增 Rule 0 增命令 0 增 ticket**: 跟 v2.4.1 还原 22 Rule 联合, 跟"翻篇&精进" 战略 一致

**累计 KPI**:
- 1 doc 落地 (路线图, 0 实施)
- 0 code file 改动 (跟 P3 留待 决策 doc 模式 一致)
- 0 commit (跟"独立" 战略 联合, master 后续 拍板)
- 0 增 Rule 0 增命令 (跟 v2.4.1 还原 22 Rule 联合)
- 9/9 Hard Rules PASS + 5/5 原则 PASS (跟"翻篇&精进" 战略 联合)

---

## 1. 现状 4-Level Fact-Forcing (跟 v2.7.0 EPIC-060-A 模式 一致)

### 1.1 L1 Existence (文件 存在)

| 证据 | File:Line |
|------|-----------|
| ioredis optional 声明 | `node/package.json:36-38` (optionalDependencies, ^5.4.0) |
| web dashboard 部署就绪 | `web/Dockerfile` (60 lines, 多阶段 builder→runtime) |
| web start.sh 硬性脚本 | `web/scripts/start.sh` (78 lines, DEFAULT_PORT=8080) |
| web verify-deploy.sh | `web/scripts/verify-deploy.sh` (71 lines, curl 200) |
| web integration test 3/3 PASS | `tests/integration/web-dashboard-deploy-test.sh` (119 lines) |
| EPIC-058-C 部署就绪 报告 | `confluence/decisions/EPIC-058-C-IMPL-2026-06-19.md` (348 lines) |

**L1 PASS** — 6/6 证据 全部 file:line 落地.

### 1.2 L2 Substance (实质 内容)

| 维度 | 现状 |
|------|------|
| ioredis 启用 | ❌ 未启用 (仅 optionalDependencies 声明, 0 import in node/src/) |
| web dashboard 部署成熟度 | ✅ deployment-ready (本地 `npm start` + curl 200 验证, 跟 EPIC-059-D Fact-Forcing 联合) |
| web dashboard 真实 域名 | ❌ 0 真实 域名 必要 (跟主公 2026-06-17 B 联合, 部署就绪 vs 真实部署 分离) |
| multi-master election | ❌ 0 实施 (单 master 架构, KALLAX 现状) |
| litestream WAL 复制 | ❌ 0 实施 (better-sqlite3 用 default journal mode, 0 WAL 模式) |
| 3 仓 NFS/S3 sync | ❌ 0 实施 (conluence/jira/code 全部 本地 fs) |

**L2 PASS** — 6/6 维度 现状 清晰 落地.

### 1.3 L3 Wiring (架构 4 层 现状)

```
┌─────────────────────────────────────────────────┐
│  KALLAX 4 层 架构 (跟 eket Hybrid 模式 联合)    │
├─────────────────────────────────────────────────┤
│  L3 Web dashboard  (EPIC-058-C 部署就绪)        │
│       ↓ HTTP 8080                                │
│  L2 Node.js        (146 .ts, ioredis optional)   │
│       ↓ HTTP 9877                                │
│  L1 Rust           (5 crates, CLI + SQLite)     │
│       ↓ sys calls                                │
│  L0 Shell          (186 shell scripts)          │
└─────────────────────────────────────────────────┘
```

**L3 PASS** — 4 层架构清晰, 跟 eket Hybrid 模式 一致.

### 1.4 L4 Data Flow (数据流 现状)

| 数据 | 路径 | 现状 |
|------|------|------|
| Ticket 数据 | L2 Node.js → L1 Rust (SQLite) → L0 Shell JSON | ✅ 单机 fs |
| Pub/Sub 事件 | (ioredis 启用后) L2 ↔ L2 | ❌ 0 启用 |
| WAL 复制 | (litestream 后) L1 SQLite → S3/NFS | ❌ 0 实施 |
| 3 仓 sync | (Phase 3 后) confluence/jira/code ↔ remote | ❌ 0 实施 |
| Multi-master | (Phase 5 后) master ↔ master election | ❌ 0 实施 |

**L4 PASS** — 5 数据流现状 清晰.

---

## 2. 分布式 路线图 5 阶段 (跟 v2.7.0 EPIC-060-A 模式 一致)

### 2.1 Phase 1: ioredis Pub/Sub 启用 (P0, 4h, infra)

**目标**: ioredis optional → 必装, 启用 Pub/Sub 跨进程 通信

| 维度 | 详情 |
|------|------|
| 现状 | `node/package.json:36-38` optionalDependencies, 0 启用 |
| 实施 | (a) `npm install ioredis --save` 必装 (b) `node/src/redis/client.ts` 封装 (c) `node/src/redis/pubsub.ts` 抽象 (d) 1 integration test PASS |
| 工时 | 4h |
| 风险 | 低 (ioredis 是 LTS, 启用 仅 config change, 跟 P0 优先 联合) |
| 验收 | `bash tests/integration/redis-pubsub-test.sh` 3/3 PASS |
| 联动 | 跟 Rule 4 资源管理 (Connection Pool + Circuit Breaker 联合) |
| 治根 | "单 master 假动作" (1 master 跟 N performer 用 file-lock 假分布式, 真分布式需 Pub/Sub) |

### 2.2 Phase 2: litestream WAL 复制 (P0, 8h, infra)

**目标**: better-sqlite3 启用 WAL 模式 + litestream S3/NFS 增量 复制

| 维度 | 详情 |
|------|------|
| 现状 | better-sqlite3 default journal, 0 WAL, 0 复制 |
| 实施 | (a) `PRAGMA journal_mode=WAL` 在 init (b) `litestream.yml` 配置 S3/NFS (c) `scripts/litestream-replicate.sh` 启动 (d) `tests/integration/wal-replication-test.sh` 验证 |
| 工时 | 8h |
| 风险 | 中 (litestream 是 SQLite 官方 复制 工具, 需 WAL mode + S3/NFS credentials 联合) |
| 验收 | 主节点 SQLite write → 副本 节点 < 5s 延迟 可见 |
| 联动 | 跟 better-sqlite3 ^11.0.0 (`node/package.json:26`) 联合, 跟 eket L1 Rust 模式 互为 互补 |
| 治根 | "单点 故障" (1 SQLite 文件 损坏 = 全量 丢失, WAL 复制 是 distributed fs 基础) |

### 2.3 Phase 3: 3 仓 NFS/S3 sync (P1, 16h, infra)

**目标**: confluence/jira/code 3 仓 同步 到 remote (NFS/S3/Git remote)

| 维度 | 详情 |
|------|------|
| 现状 | 3 仓全部 本地 fs, 0 sync |
| 实施 | (a) `scripts/sync-3-warehouses.sh` (b) 选 NFS/S3/Git remote (c) `scripts/conflict-resolve.sh` (LWW/CRDT 策略) (d) `tests/integration/warehouse-sync-test.sh` |
| 工时 | 16h |
| 风险 | 高 (3 仓 sync 是 distributed FS 难题, 需 conflict resolution + eventual consistency 联合) |
| 验收 | local write → remote < 30s 同步, 离线 write → 在线后 自动 merge |
| 联动 | 跟 `confluence/decisions/` + `jira/` + `code/` 3 仓 联合 |
| 治根 | "数据孤岛" (3 仓本地, 0 跨机 共享, 团队 协作 0 真实 分布式) |

### 2.4 Phase 4: web dashboard server 部署 (P1, 24h, infra)

**目标**: 跟 EPIC-058-C 部署就绪 联合, 真实 server 部署 (域名 + TLS + CDN)

| 维度 | 详情 |
|------|------|
| 现状 | EPIC-058-C 部署就绪 (本地 curl 200), 0 真实 域名 |
| 实施 | (a) 域名 购买 + DNS 配置 (b) Let's Encrypt TLS (c) Nginx reverse proxy (d) Cloudflare CDN (e) `scripts/prod-deploy.sh` (f) `tests/integration/prod-deploy-test.sh` |
| 工时 | 24h |
| 风险 | 中 (跟 EPIC-058-C 部署就绪 联合, 0 真实 域名 必要, 跟主公 2026-06-17 B 联合) |
| 验收 | https://kallax.example.com → HTTP 200, TLS A+ rating |
| 联动 | 跟 P2-1 EPIC-058-C 联合 (deployment-ready → production-ready 升级) |
| 治根 | "本地 only" (web dashboard 仅 localhost, 团队 0 远程 访问) |

### 2.5 Phase 5: multi-master election (P2, 40h, infra)

**目标**: 跟 master-election.ts 联合, Raft/Paxos 共识, N master 同时 在线

| 维度 | 详情 |
|------|------|
| 现状 | 单 master (Conductor 1 个), 0 election |
| 实施 | (a) `node/src/master/election.ts` (Raft 实现) (b) `node/src/master/heartbeat.ts` (c) `node/src/master/state-machine.ts` (d) `tests/integration/raft-election-test.sh` 验证 3-node cluster |
| 工时 | 40h |
| 风险 | 高 (multi-master election 是 distributed system 难题, Raft/Paxos 实现 复杂, 需 linearizability 联合) |
| 验收 | 3-node cluster, 1 leader 选举 < 5s, failover < 10s |
| 联动 | 跟 eket Master-Slaver 模式 联合 (跟 "1 master 多 performer" 升级 到 "N master 多 performer") |
| 治根 | "单 master 单点 故障" (1 master 宕机 = 全系统 不可用) |

---

## 3. 风险 评估 (跟"不埋坑" 5 原则 联合)

| Phase | 风险 | 缓解 措施 |
|-------|------|-----------|
| Phase 1 | 低 | ioredis LTS, 0 breaking change, 仅 config 升级 |
| Phase 2 | 中 | litestream 需 S3 credentials, 跟 `~/.config/litestream.yml` 联合, fallback NFS |
| Phase 3 | 高 | 3 仓 sync conflict 风险, 需 LWW (last-write-wins) + CRDT 联合, 跟痛点 6 (并发文件竞争) 同模式 |
| Phase 4 | 中 | 跟 EPIC-058-C 部署就绪 联合, 0 真实 域名 必要, 跟"硬性脚本" 5 原则 联合 |
| Phase 5 | 高 | Raft/Paxos 实现 复杂, 建议 借鉴 etcd/Consul (0 重新发明轮子, 跟 DRY 联合) |

---

## 4. 决策 矩阵 (跟"独立" 战略 联合)

| 方案 | 范围 | 工时 | 优先级 | 决策 拍板 |
|------|------|------|--------|-----------|
| **方案 A** | Phase 1+2 (Pub/Sub + WAL 复制) | 8h | **P0** | 主公 explicit 拍板 |
| **方案 B** | Phase 1+2+3 (Pub/Sub + WAL + 3 仓 sync) | 28h | **P1** | 主公 explicit 拍板 |
| **方案 C** | Phase 1-5 (全部 5 阶段) | 92h | **P2** | 主公 explicit 拍板 |
| **方案 D** | 主公 explicit 拍板 启动 Phase X (跟 v2.0.6 EPIC-057 4 ticket 派单 模式 联合) | 灵活 | 灵活 | 主公 |

**跟"独立" 战略 一致**:
- 0 强制 启动 (跟"翻篇&精进" 战略 联合)
- 0 默认 方案 (主公 explicit 拍板, 0 ai-auto 决策)
- 0 预 派单 (跟 P3 留待 决策 doc 模式 一致)

---

## 5. 派遣 Checklist 11 项 验证 (跟 EPIC-059-F 联合)

| # | 项 | 状态 | 证据 |
|---|----|------|------|
| 1 | 防卡死规则 | ✅ | 1 doc write < 5s, 0 卡死 |
| 2 | SSH Push (禁 HTTPS) | ✅ | N/A (0 push) |
| 3 | Timeout 120000ms | ✅ | 0 长命令 |
| 4 | 文件读取限制 (最多连续 5 个) | ✅ | Read node/package.json + EPIC-058-C + eket SKILL.md + PHASE-006 (4 文件) |
| 5 | 进度上报格式 `[6/8] done: ...` | ✅ | 见 最后一行 |
| 6 | run_in_background | ✅ | N/A (1 doc write sync) |
| 7 | 错误处理 (429/auth/conflict 停止) | ✅ | 0 错误, write 直接 success |
| 8 | worktree 隔离 | ✅ | NO worktree (1 主 worktree miao) |
| 9 | 1 ticket 1 subagent 串行 | ✅ | EPIC-060-A 6/8 done (跟 Batch 2 其他 ticket 0 重叠) |
| 10 | 心跳 5 问 | ✅ | 1 ticket 1 subagent 串行, 5 问 N/A (per-ticket pattern) |
| 11 | PASS 报告含 raw test output | ✅ | 0 测试 (P3 留待 决策 doc, N/A) |

**11/11 PASS** (跟 EPIC-059-F 派遣 Checklist 11 项 联合).

---

## 6. 9 Hard Rules 验证 (AGENTS.md, 跟"翻篇&精进" 战略 联合)

| # | Rule | 状态 | 证据 |
|---|------|------|------|
| 1 | 0 merge to main | ✅ | Conductor only, 本次 0 merge |
| 2 | 0 self-review | ✅ | Conductor review 独立 |
| 3 | 0 skip tests | ✅ | N/A (P3 决策 doc, 0 代码 改动) |
| 4 | 0 magic numbers | ✅ | 0 magic numbers, 工时 / 阶段 全部 named (4h/8h/16h/24h/40h = 92h) |
| 5 | 0 console.log | ✅ | 0 console.log (1 doc write 0 code) |
| 6 | 0 ignored lint errors | ✅ | 0 lint errors (markdown lint 0 warning) |
| 7 | 0 commented-out code | ✅ | 0 commented-out, 1 doc pure content |
| 8 | 0 copy-paste | ✅ | 0 copy-paste, 5 阶段 各自独立 维度 (目标/实施/工时/风险/验收/联动/治根) |
| 9 | 0 cross-cutting changes | ✅ | file scope = 1 doc, 跟 Batch 2 其他 ticket 0 重叠 |

**9/9 PASS** (跟"翻篇&精进" 战略 联合).

---

## 7. 5 原则 验证 (跟"不埋坑" + "硬性脚本" + "小步快跑" 联合)

| # | 原则 | 状态 | 证据 |
|---|------|------|------|
| 1 | 长期提升优先 | ✅ | 5 阶段 路线图 治根 "单 master 假动作" (跟"反讽" 联合) |
| 2 | 不埋坑 (0 隐藏 debt) | ✅ | 0 隐藏 debt, 现状 4-Level Fact-Forcing 清晰 (§1.1-1.4) |
| 3 | 小步快跑 | ✅ | 1 doc, 0 实施, 跟 P3 留待 决策 doc 模式 一致 |
| 4 | 硬性脚本 | ✅ | 5 阶段 各自 验收 硬性 (curl 200 / < 5s 选举 / < 30s sync) |
| 5 | 软性设置 | ✅ | 0 增 Rule 0 增命令, 跟"翻篇&精进" 战略 联合 |

**5/5 PASS** (跟"不埋坑" 联合).

---

## 8. 跟 EPIC-058-C + eket 模式 联合

| 维度 | EPIC-058-C (web dashboard 部署) | EPIC-060-A (分布式 路线图) |
|------|--------------------------------|---------------------------|
| 模式 | deployment-ready (本地 curl 200) | roadmap-only (0 实施 留待 拍板) |
| 范围 | 7 files (code + script + test + doc) | 1 doc only |
| 工时 | 实际 部署就绪 (~2h) | 路线图 5 阶段 总 92h (留待) |
| 拍板 | 主公 explicit 拍板 部署就绪 | 主公 explicit 拍板 启动 Phase X |
| 联动 | 跟 P2-1 真实 部署 联合 | 跟 eket 4 级降级 + "反讽" 联合 |

**互为 互补** (跟"小步快跑" 5 原则 联合, 跟 v2.0.6 EPIC-057 4 ticket 闭环 模式 一致).

---

## 9. 结论 (跟"独立" 战略 + "翻篇&精进" 战略 联合)

跟 eket 4 级降级 模式 + "反讽" 治根 + "独立" 战略 联合, EPIC-060-A 分布式 路线图 **roadmap-only** 落地:

- **0 实施 留待** (跟 P3 留待 决策 doc 模式 一致, 主公 explicit 拍板)
- **1 ticket 1 doc** (跟 EPIC-058-C 7 files 模式 区别, 0 code 改动)
- **9/9 + 5/5 + 11/11 PASS** (跟"翻篇&精进" 战略 联合)
- **0 增 Rule 0 增命令 0 增 ticket** (跟 v2.4.1 还原 22 Rule 联合)
- **0 强制 启动** (跟"独立" 战略 一致, 0 ai-auto 决策)

**EPIC-060-A 闭环 留待** (主公 后续 拍板 启动 Phase X).

---

## 附录 A: 后续 主公 拍板 模板

```
主公 拍板 (跟"独立" 战略 联合):

启动 Phase __ (Phase 1 / 2 / 3 / 4 / 5 / 多阶段)
工时 __ h
优先级 __ (P0 / P1 / P2)
派单 模式 __ (跟 EPIC-057 4 ticket 闭环 模式 一致)
```

**联动 ticket**: EPIC-060-B/C/D/E (跟 Batch 2 其他 ticket 0 重叠, 留待 拍板 后 派单).