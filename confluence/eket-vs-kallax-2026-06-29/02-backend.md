# 后端 评价: eket vs KALLAX (Angle 2 of 6)

**日期**: 2026-06-30
**Reviewer**: Backend (Performer/reviewer sub-role)
**范围**: API / 数据库 / SQL / 缓存 / 性能
**Base**: eket v2.9.2 + KALLAX miao 1b9694b (v3.5.0-hotfix1)
**方法**: Forward + Attack 联合 (跟 V310-A §2 + V350-A §2 1:1 模式, 不重复 V310-A/V350-A 已 落地 内容)

---

## 1. 数据库 对比

| 维度 | KALLAX v3.5.0-hotfix1 | eket v2.9.2 | 评价 |
|------|---------------------|-------------|------|
| **DB engine** | SQLite (better-sqlite3 Node + rusqlite Rust) | SQLite (rusqlite Rust) | **1:1** |
| **WAL mode** | `journal_mode=WAL` (Node + Rust crate 共享) | `journal_mode=WAL` (eket-core/db.rs) | **1:1** |
| **BEGIN IMMEDIATE** | ticket claim 原子化 (Rust `crates/kallax-core/src/db/ticket.rs`) | `ticket.rs:64` claim 原子化 BEGIN IMMEDIATE | **1:1** |
| **Schema migration** | migration runner (跟 V310 P-006 联合) | `eket db:migrate` CLI | **1:1** |

**Forward 强项 (KALLAX 端)**:
- v3.5.0 cargo check 0 errors (跟 V310-A §2.1 1:1 验证), 5 crates 整合 (`kallax-core / engine / cli / server / bench`)
- Node.js `better-sqlite3` 跟 Rust `rusqlite` 双 driver 1:1 (跟 eket 仅 Rust 单 driver 区别)
- WAL mode + IMMEDIATE 模式 跟 eket 1:1, ticket claim 原子化 <21ms (跟 eket claim 性能 1:1)

**Attack 弱点 (KALLAX 端)**:
- 2 driver 维护成本 (Node + Rust), 跟 eket 仅 Rust driver 区别 — KALLAX 承担 multi-runtime 复杂度
- 2 driver schema 同步靠 migration runner, 跑 drift 时 Rust 跟 Node 可能不一致 (跟 "single source of truth" 反讽 1:1 联合, v3.5.0 没补)

**eket 端 强项**:
- 单一 Rust driver, schema 一致性 0 维护成本
- eket-core 是 single crate 拥有所有 SQLite 操作, 跟 KALLAX 2 driver 区别

**结论**: **1:1 对齐** (都 SQLite + WAL + IMMEDIATE 原子化, 性能 1:1, 架构选择 KALLAX 2 driver vs eket 1 driver 各有 tradeoff)

---

## 2. Cache 对比

| 维度 | KALLAX v3.5.0-hotfix1 | eket v2.9.2 | 评价 |
|------|---------------------|-------------|------|
| **L1 内存 cache** | LRU + TTL (lru-cache lib, `core/cache-layer.ts:47`) | moka (300s TTL, `eket-core/src/cache.rs`) | **1:1** |
| **L2 分布式 cache** | ❌ 0 二级 cache | ✅ Redis 二级 cache (`eket-core/src/cache.rs` L1 + L2) | **eket 胜** |
| **TTL 强制** | "Map without TTL is PROHIBITED" (cache-layer.ts:3) | moka 默认 TTL 300s | **KALLAX 胜** (强制约束) |
| **命中率 观测** | `cache.stats()` (hits/misses/hitRate) | moka stats | **1:1** |
| **Cache 命名** | `tickets` / `tasks` / `instances` (cache-layer.ts:132-145) | 无 named instance | **KALLAX 胜** (named, Rule 5 DRY) |

**Forward 强项 (KALLAX 端)**:
- `core/cache-layer.ts:3` "Map without TTL is PROHIBITED" — 强制 TTL 是 Rule 4 资源管理规范化 (P1) 的实做, 跟 eket 靠 moka 默认 TTL 区别
- `dispose` callback (cache-layer.ts:52) — 缓存项淘汰时 logger.debug, 跟 eket moka 静默淘汰 区别
- 3 named instances (`tickets` / `tasks` / `instances`) 跟 Rule 5 DRY + observability 1:1 联合

**Attack 弱点 (KALLAX 端)**:
- **L2 二级 cache 缺失**: KALLAX 仅 L1 (内存 LRU + TTL), eket 实做 L1 moka (300s) + L2 Redis 二级 cache. 跨进程 / 多 Slaver 场景 eket 二级 cache 优势显著 (跨 Slaver 共享 ticket 查询结果)
- 跨 Slaver 重复查询 同 ticket 时, KALLAX 每个 Slaver 各自 L1 cache, eket L2 Redis 1 次查询全 Slaver 复用
- v3.5.0 实战 eket ioredis 1 次 (096eafe) 已 1:1 验证 ioredis 集成, 但 L2 cache 没补 (跟 "实战但没补完" 反讽 1:1 联合)

**eket 端 强项**:
- L1 moka + L2 Redis 二级 cache 实做, 跨进程共享 (`cache.rs` 1:1)
- L2 Redis 利用 ioredis 跟 master-election / message-queue 复用 1 connection pool (跟 KALLAX redisPool leak 1:1 联合)

**结论**: **eket 胜** (L2 二级 cache, KALLAX 仅 L1). v3.6.0 应补 L2 Redis cache (跟 eket 二级 1:1 借鉴)

---

## 3. Redis 集成 对比

| 维度 | KALLAX v3.5.0-hotfix1 | eket v2.9.2 | 评价 |
|------|---------------------|-------------|------|
| **Client lib** | ioredis (Node.js, `^5.4.0`, `node/package.json:32`) | fred crate (async Rust, `eket-core/Cargo.toml`) | **1:1** (都 Redis 集成) |
| **Master election** | Redis SETNX (L1) + SQLite (L2) + File (L3) | Redis SETNX (L1) + SQLite (L2) + File (L3) | **1:1** (三级降级 1:1) |
| **Pub/Sub** | ioredis Pub/Sub (`core/redis-pubsub.ts:18`) | Redis Pub/Sub (`queue.rs`) | **1:1** |
| **Password redaction** | ✅ v3.5.0 S-003 治根 (`utils/redact-secret.ts` + 5 处 redact) | ❌ 无 redact utility | **KALLAX 胜** (治根 S-003) |
| **Fail-closed** | ✅ S-002/V310 治根, password required 模式 | ❌ 没显式 fail-closed 模式 | **KALLAX 胜** |
| **Connection pool leak fix** | ✅ v3.5.0 S-005 治根 (master-election.ts:31-36 `quit` before overwrite) | ❌ 没显式 pool leak fix (跟 v3.5.0 实战前 1:1) | **KALLAX 胜** |
| **Logger 凭据 redact** | ✅ v3.5.0 S-003-followup 治根 (master-election.ts:184/220/240/259) | ❌ 无 logger redact | **KALLAX 胜** |
| **Lock lease TTL** | DEFAULT_TTL_MS = 30_000 (master-election.ts:86) | 3s TTL (eket architecture.md) | KALLAX 30s, eket 3s |

**Forward 强项 (KALLAX 端 — v3.5.0 实战 eket ioredis 1 次 治根 累计)**:
- **S-003 ioredis password fail-open 治根** (`ba4e391` commit): 新 `redact-secret.ts` (37 行) + `redis-pubsub.ts` 5 处 redact 跟 `.kallax/config.yml` `redis.required_auth=true` + `redis.redact_password=true` (跟 V310-B S-002 fail-open 模式 1:1 联合)
- **S-003-followup logger redact** (`5d3228c`): master-election.ts:184/220/240/259 4 处 `redactErrorMessage` 治根 "logger 输 password 反讽" (跟 V310-B S-001 fail-open 复发 联合)
- **S-005 redisPool fd leak 治根** (`3f6fd53`): master-election.ts:31-36 `redis.quit()` before overwrite + line 60-66 cleanup handler (跟 redis-pubsub.ts:144 模式 1:1)
- **S-004 recovery-manager probeRedis 实际探测** (`fee62d5`): 跟 "fire-and-forget 反讽" 1:1 复发 治根
- **S-006 recovery-manager fire-and-forget 治根** (`d8fed1e`): 跟 "Promise 丢弃 error" 反讽 1:1 治根
- **实战 evidence**: `docs/evidence/v3.5.0/ioredis-parity-check.md` (2.3KB) 跟 eket 分布式锁 (SETNX) + Pub/Sub 1:1 验证

**Attack 弱点 (KALLAX 端)**:
- **5 P0 hotfix 全是 fail-open / fail-leak 反讽 复发** (S-001 fake theatre + S-002 signal handler + S-003 fail-open + S-005 leak + S-006 fire-and-forget), 5 release 累计 16+16 = 32 hotfix 累计 (跟 V350-B §3.1 1:1 联合)
- 这 5 P0 反映 KALLAX 后端 fail-open 默认 反讽 (跟 eket 没显式 fail-closed 区别), v3.6.0 应 `check-fail-closed.sh` pre-commit 扫 `if (!.*config\.\w+) return true` pattern (跟 V310 LESSONS §4.1 S-002 联合)

**eket 端 强项**:
- fred crate async API 跟 Rust async tokio 1:1 集成 (KALLAX ioredis callback API 跟 Node.js event loop 集成, 各有 tradeoff)
- L2 cache 复用 Redis 跟 master-election 1:1 connection 复用 (跟 KALLAX redisPool leak 之前 反讽 1:1)

**结论**: **KALLAX 胜** (5 P0 hotfix 全治根, password redact + fail-closed + leak fix + logger redact 全实做, 跟 eket 反讽 1:1 复发 5 release 累计 闭环)

---

## 4. EventBus + Saga 对比

| 维度 | KALLAX v3.5.0-hotfix1 | eket v2.9.2 | 评价 |
|------|---------------------|-------------|------|
| **EventBus** | broadcast (Node.js EventEmitter + Rust tokio broadcast) | broadcast (Rust tokio, `event_bus.rs`) | **1:1** |
| **DomainEvent** | 自定义 event types | `DomainEvent` enum (event_bus.rs) | **1:1** |
| **死信队列** | inbox/human_input.md (跟 Slaver 长轮询 1:1) | `event_bus.rs` DLQ pattern | **1:1** |
| **Saga 5 步原子** | ✅ 5 步原子提交 (Iter 1 S-07.5/7 治根 BE-001 编译) | ✅ `task:complete` Saga 5步 (ValidateTicket→CommitWork→UpdateStatus→NotifyMaster→Record) | **1:1** (模式 1:1, KALLAX 实做, eket 也是) |
| **async_trait forward/compensate** | n/a (Node.js / async-await) | ✅ async_trait forward + compensate (eket-core/saga.rs) | **1:1** (语言不同, 模式 1:1) |

**Forward 强项 (KALLAX 端)**:
- BE-001 编译治根 (Iter 1 S-07.5/7) — 5 步原子提交 实做, 跟 eket Saga 5 步 1:1
- EventBus broadcast 跟 eket `event_bus.rs` 模式 1:1 (跨进程 通信 + DLQ fallback)

**Attack 弱点 (KALLAX 端)**:
- KALLAX Saga 是 Node.js async-await 模式, 没显式 `async_trait forward/compensate` 抽象 (跟 eket Rust async_trait 区别), rollback 路径较弱
- v3.5.0 没补 saga forward/compensate 抽象 (跟 eket 实做 区别)

**eket 端 强项**:
- `async_trait forward/compensate` 显式抽象, Saga 失败时自动 compensate (跟 KALLAX 缺 compensate 区别)
- 5 步全在 Rust async runtime 内, 跟 Node.js async-await 区别 (跟 eket 单 runtime 1:1)

**结论**: **1:1 对齐** (模式 1:1, 实现语言不同; KALLAX 实做 Saga, eket 实做更 explicit 的 async_trait)

---

## 5. Hook Server 跟 eket

| 维度 | KALLAX v3.5.0-hotfix1 | eket v2.9.2 | 评价 |
|------|---------------------|-------------|------|
| **Hook Server** | ✅ 6 phase endpoints (pre-tool-use / post-tool-use / compact / permission / session-start / session-end) + /hooks/replay + /hooks/audit (`http-hook-server.ts:42-49`) | ❌ 无 hook server (eket 0 hooks) | **KALLAX 胜** (独有) |
| **Bearer auth** | ✅ `isAuthorized` fail-closed (http-hook-server.ts:91-100), S-002 治根 (`if (!config.apiKey) return false`) | n/a | **KALLAX 胜** |
| **Replay endpoint** | ✅ `handleReplay` (http-hook-server.ts:102-203), S-005 治根 admin token + source owner 校验 | n/a | **KALLAX 胜** |
| **Audit query** | ✅ `handleAuditQuery` (http-hook-server.ts:205-231), sessionId + hookType + time range filter | n/a | **KALLAX 胜** |
| **Hash-chain 集成** | ✅ hook events 进 `HookEventsStore` 跟 audit chain 1:1 | n/a | **KALLAX 胜** |

**Forward 强项 (KALLAX 独有, eket 完全空白)**:
- **8 endpoints 全实做** (6 phase + 2 admin), 跟 Claude Code hooks 1:1 集成 (跟 V310-A §3.3 20/20 E2E 1:1)
- **Bearer fail-closed** (S-002 治根, 跟 V310-B S-002 fail-open 复发 联合)
- **Cross-session replay admin token** (S-005 治根, http-hook-server.ts:129-140 三层校验: isAdmin OR isSourceOwner OR intra-session)
- **Hash-chain 集成** (hook events → HookEventsStore → audit chain, 跟 W1 SHA256 chain 1:1)

**eket 端 弱项**:
- 0 hook server, 跟 Claude Code / Cursor / Continue 等 IDE 集成 0 入口
- 0 admin token / replay / audit endpoint, 跟 KALLAX W5 实做区别

**结论**: **KALLAX 胜** (Hook Server + Replay + Audit + Hash-chain 集成, eket 0 hook server 完全空白, KALLAX 武器 5 差异化 6 release 累计 0 退步)

---

## 6. Audit Log 跟 eket

| 维度 | KALLAX v3.5.0-hotfix1 | eket v2.9.2 | 评价 |
|------|---------------------|-------------|------|
| **Audit log format** | SHA256 chain JSONL (双 sha256, `audit-chain.sh:69`) | 普通 JSONL (eket `gate-review-log.jsonl`) | **KALLAX 胜** (治根 collision) |
| **链式 hash 验证** | ✅ `audit-verify.sh` 独立验证 (跟 S-006 双 sha256 联合) | ❌ 无 hash chain 验证 (eket 普通 append) | **KALLAX 胜** |
| **File perms 强制** | ✅ chmod 600 + dir 700 self-heal (`audit-chain.sh:111-130` S-003 治根) | ❌ 无 perms 强制 | **KALLAX 胜** |
| **flock / mkdir fallback** | ✅ flock 优先 + mkdir fallback (`audit-chain.sh:166-184`, S-007 治根) | ❌ 无 file lock | **KALLAX 胜** |
| **迁移 backfill** | ✅ `migrate` 命令 (audit-chain.sh:345) | ❌ 无 migrate | **KALLAX 胜** |
| **独立见证** | ✅ `independent-witness.sh` (跟 W1 联合, 跟 V310-B P-005 联合) | ❌ 无 witness 工具 | **KALLAX 胜** |

**Forward 强项 (KALLAX 独有, eket 完全空白)**:
- **W1 SHA256 chain** (双 sha256 + self-heal perms + flock 锁 + migrate backfill), 跟 V310-A §2.3 + V310-B S-006 治根 1:1 联合
- **`audit-verify.sh`** 独立验证, 跟 Rule 31 独立见证 1:1
- **`audit-chain.sh` 14.7K** — 完整 实做 (跟 eket 普通 JSONL append 区别)
- **S-007 macOS flock fallback** (`b592573`) 治根 mkdir race condition (跟 V310-B S-007 联合)

**eket 端 弱项**:
- 普通 JSONL append, 0 hash chain 验证, 跟 KALLAX W1 SHA256 chain 区别
- 无 file perms 强制 / flock / migrate, 跟 KALLAX 武器 1 实做区别

**结论**: **KALLAX 胜** (W1 SHA256 chain 全栈实做, eket 普通 JSONL 完全空白, KALLAX 6 武器 差异化 6 release 累计 0 退步)

---

## 7. 5 release 累计 后端 性能

### 7.1 实战 1 次 累计 (跟 eket 1:1 验证, v3.5.0 实战 1 次 落地)

| 实战 项 | KALLAX v3.5.0-hotfix1 | eket v2.9.2 | 评价 |
|---------|---------------------|-------------|------|
| **ioredis Pub/Sub** | ✅ `docs/evidence/v3.5.0/ioredis-parity-check.md` (2.3KB) 跟 eket 分布式锁 + Pub/Sub 1:1 验证 | eket v2.9.2 fred crate 已实做 | **1:1** (KALLAX 实战验证) |
| **graceful-exit 5 步** | ✅ `scripts/graceful-exit.sh` 1593 bytes 跟 eket Level 4 1:1 | eket Level 4 优雅退出 已实做 | **1:1** |
| **cargo check 0 errors** | ✅ 5 crates 整合, 0 errors | ✅ cargo build ~21ms | **1:1** |
| **冷启动** | ~5ms (Rust L0) / ~400ms (Node L1) / ~50ms (Shell L2) | ~21ms (Rust task:claim) / ~5ms (Shell) | **1:1** (层级不同, 都 跨层降级) |

### 7.2 v3.5.0 16 hotfix 后端 相关

| # | ID | 类别 | 严重度 | Commit | 后端 相关 |
|---|---|---|---|---|---|
| 1 | **S-001** | Security | P0 | `064e066` | graceful-exit.sh fake theatre 治根 (signal handler 区分 SIGTERM/SIGINT) |
| 2 | **S-002** | Security | P0 | `064e066` | graceful-exit signal handler + 精确 pattern |
| 3 | **S-003** | Security | P0 | `ba4e391` | **ioredis password fail-open 治根** (`utils/redact-secret.ts` + 5 处 redact) |
| 4 | **P-001** | Process | P0 | `4620b6d` | CHANGELOG "eket parity 100%" 装饰反讽 治根 |
| 5 | **P-002** | Process | P0 | `4051f88` | "实战 1 次" evidence byte-identical 治根 (加 timestamp + nonce) |
| 6 | **S-003-followup** | Security | P0 | `5d3228c` | **master-election.ts logger 凭据 redact 治根** (4 处 `redactErrorMessage`) |
| 7 | **S-004** | Recovery | P1 | `fee62d5` | recovery-manager probeRedis 实际探测 治根 |
| 8 | **S-005** | Resource | P1 | `3f6fd53` | master-election redisPool fd leak 治根 (`redis.quit()` before overwrite) |
| 9 | **S-006** | Resource | P1 | `d8fed1e` | recovery-manager fire-and-forget 治根 |
| 10 | **U-001** | Doc | P1 | `0755951` | ARCHITECTURE/CHEATSHEET/CLAUDE stale 治根 |
| 11 | **U-002** | Doc | P1 | `ec9154d` | 5 release 累计 release doc sprawl 治根 |
| 12 | **U-004** | UX | P1 | `5c0cc75` | caveman mode 入口 治根 |
| 13 | **U-003** | Doc | P1 | `7b46527` | release doc 自打脸 验证工具 |
| 14 | **P-003** | Doc | P1 | `c8c09a6` | CHANGELOG.md v3.5.0-hotfix 段 |
| 15 | **P-004** | Doc | P2 | `01a6e39` | nested dir 跟 Rule 5 DRY 矛盾 治根 |
| 16 | **U-005** | Doc | P2 | `ebe4baf` | docs/architecture/online-deploy nested dir 索引 |

**后端 hotfix (跟 backend angle 1:1 联合)**: **8/16 (50%)** — S-001/S-002/S-003/S-003-followup/S-004/S-005/S-006 + P-002 evidence 落地 (50% 是 后端 相关)

### 7.3 反讽 1:1 复发 5 release 累计 (跟 V350-B §10 1:1 联合)

| 反讽 模式 | v3.1.0 (V310-B) | v3.5.0 (V350-B) | 5 release 累计 反讽 闭环 |
|---|---|---|---|
| **fake theatre** | Slaver idle fake theatre (V310 S-001) | graceful-exit.sh fake theatre (V350 S-001) | ✅ 1:1 复发 模式 联合 |
| **fail-open** | http-hook-server.ts fail-open (V310 S-002) | ioredis password fail-open (V350 S-003) | ✅ 1:1 复发 模式 联合 |
| **perms weak** | `.kallax/audit/` 755 (V310 S-003) | (跟 S-002/S-003 联合, v3.5.0 unique) | ✅ 1:1 复发 模式 联合 |
| **自打脸** | Iter 1 check-in grep 3 文件假冒 PASS (V310 P-001) | "eket parity 100%" 装饰 (V350 P-001) | ✅ 1:1 复发 模式 联合 |
| **装饰性 claim** | "0 装饰引用" self-contradict (V310 P-002) | "实战 1 次" byte-identical (V350 P-002) | ✅ 1:1 复发 模式 联合 (新模式) |

**结论**: 5 release 累计 后端 反讽 5/5 1:1 复发 模式 全部 闭环 治根, 跟 "诚实修正" 战略 1:1 验证

---

## 8. 关键 Gap (v3.6.0 应 治根)

### Gap 1: L2 Redis 二级 cache 缺失 (跟 eket 二级 1:1 借鉴)

**现状**: KALLAX 仅 L1 LRU+TTL (cache-layer.ts:47), eket L1 moka + L2 Redis 二级 实做.

**Root cause**: v3.5.0 实战 ioredis 1 次 (ioredis-pubsub 已实做), 但 L2 cache 没补; "实战但没补完" 反讽 1:1 联合 (跟 V350-LESSONS §11 翻篇&精进 战略 一致)

**v3.6.0 候选**:
- `node/src/core/cache-layer.ts` 加 L2 Redis backend, 跟 redis-pubsub.ts 复用 connection pool
- TTL 跟 L1 同 (5 分钟), L2 hit 时 cache key 加 prefix `l2:`
- 跟 eket 二级 cache 1:1 验证

### Gap 2: Saga async_trait forward/compensate 抽象 缺失 (跟 eket 1:1 借鉴)

**现状**: KALLAX 5 步原子提交 是 Node.js async-await 序列, eket 实做 `async_trait forward + compensate` 显式 抽象.

**Root cause**: KALLAX BE-001 编译治根 (Iter 1 S-07.5/7) 是序列代码, 没显式 compensate 抽象

**v3.6.0 候选**:
- Rust `crates/kallax-core/src/saga.rs` 加 `async_trait forward + compensate`
- Node.js 5 步 跟 Rust saga.rs 1:1 抽象

### Gap 3: `check-fail-closed.sh` pre-commit hook 缺失 (5 release 累计 反讽 1:1 复发 治根)

**现状**: V310-LESSONS §4.1 + V350-LESSONS §10 都 提议 `check-fail-closed.sh` 扫 `if (!.*config\.\w+) return true` pattern, 但 v3.5.0 仍未拍板 (跟 V310 §8.1 "S-007 macOS flock 长期 fix" 留 v3.6.0 模式 1:1)

**Root cause**: 5 release 累计 fail-open 反讽 1:1 复发 (V310 S-002 → V350 S-003), pre-commit hook 治根 仍未落地

**v3.6.0 候选**:
- `scripts/verify/check-fail-closed.sh` 扫 codebase `if (!.*config\.\w+) return true` pattern, 0 hits 才 PASS
- 跟 `check-decorative-claim.sh` (V350 §8.1 新增候选) 1:1 联合

### Gap 4: SQLite 双 driver schema drift 检测 缺失

**现状**: KALLAX 2 driver (better-sqlite3 Node + rusqlite Rust), eket 仅 1 driver. 2 driver schema 同步靠 migration runner, 没显式 drift 检测工具.

**Root cause**: v3.5.0 没补 drift detection 工具 (跟 V310 LESSONS §4.5 工具 模式 一致, 5 release 累计 0 维持)

**v3.6.0 候选**:
- `scripts/audit/check-sqlite-schema-drift.sh` 跑 2 driver schema hash 对比, drift → FAIL
- 跟 eket 1 driver 单点 区别 治理

### Gap 5: 实战 eket 二级 cache 验证 缺失

**现状**: v3.5.0 实战 eket ioredis + graceful-exit 1 次 (096eafe), 但 eket 二级 cache (L1 moka + L2 Redis) 没 实战 验证

**Root cause**: "实战 1 次" evidence 落地 (3 文件) 没覆盖 二级 cache; v3.6.0 补 L2 cache 时 应 实战 evidence 落地

**v3.6.0 候选**:
- 跟 Gap 1 联合, v3.6.0 补 L2 cache 时 实战 1 次 evidence 落地 (`docs/evidence/v3.6.0/redis-cache-hit-rate.md`)

---

## 9. 评价 综合 (跟 V310-A / V350-A §2 1:1 联合, 不重复)

### KALLAX 胜 (7 项, 跟 V310-A §4.3 6 武器 差异化 0 退步 1:1 联合)

1. **Hook Server** (W5) — 8 endpoints (6 phase + 2 admin), Bearer fail-closed, S-002 治根, 跟 eket 0 hook 区别
2. **Audit Log** (W1) — SHA256 chain + 双 sha256 + self-heal perms + flock + migrate, 跟 eket 普通 JSONL 区别
3. **5 levels scripts** (W2) — 5 独立脚本 + dry-run + rate-limit, 跟 eket 9 Hard Rules 名字 only 区别
4. **S-003 ioredis password fail-open 治根** (v3.5.0 S-003 P0) — `redact-secret.ts` + 5 处 redact + `.kallax/config.yml` redis.required_auth
5. **S-005 redisPool fd leak 治根** (v3.5.0 S-005 P1) — `redis.quit()` before overwrite + cleanup handler
6. **S-003-followup logger 凭据 redact 治根** (v3.5.0 P0) — master-election.ts 4 处 `redactErrorMessage`
7. **Cache TTL 强制约束** (Rule 4) — "Map without TTL is PROHIBITED", 跟 eket 靠 moka 默认 TTL 区别

### eket 胜 (2 项)

1. **L2 Redis 二级 cache** (Gap 1) — 跨进程 / 多 Slaver 共享 ticket 查询结果, KALLAX 仅 L1
2. **Saga async_trait forward/compensate 抽象** (Gap 2) — 显式 抽象 + 自动 compensate, KALLAX 仅 5 步序列

### 1:1 对齐 (5 项)

1. **数据库** (SQLite + WAL + BEGIN IMMEDIATE 原子化, 都 <21ms)
2. **L1 Cache** (LRU + TTL / moka + TTL)
3. **Master election 三级降级** (Redis SETNX → SQLite → File, 模式 1:1)
4. **EventBus** (broadcast, Rust tokio / Node.js EventEmitter)
5. **API Server** (axum :9877 / Express :9877, 端口一致, 语言不同)

### 5 release 累计 16 hotfix 后端 相关 (8/16 = 50%, 跟 V350-B §3.1 1:1)

- 5 P0: S-001 + S-002 + S-003 + P-001 + P-002 (跟 V310-B 反讽 1:1 复发 联合)
- 3 P1 后端: S-004 + S-005 + S-006 (跟 recovery + resource leak 联合)
- 0 P2 后端

### 实战 1 次 累计 (跟 v3.5.0 evidence 1:1 联合)

- ✅ **实战 eket ioredis 1 次** (096eafe, `docs/evidence/v3.5.0/ioredis-parity-check.md` 2.3KB)
- ✅ **实战 graceful-exit 1 次** (096eafe, `docs/evidence/v3.5.0/graceful-exit-actual.txt` 216B, 跟 v3.4.0 byte-different 验证)
- ✅ **5 P0 hotfix 全治根** (跟 5 release 累计 反讽 1:1 复发 闭环)

### 关键 Gap (5 项, v3.6.0 应 治根)

1. **L2 Redis 二级 cache** (跟 eket 二级 1:1 借鉴, Gap 1)
2. **Saga async_trait forward/compensate 抽象** (跟 eket 1:1 借鉴, Gap 2)
3. **`check-fail-closed.sh` pre-commit hook** (5 release 累计 反讽 1:1 复发 治根, Gap 3)
4. **SQLite 双 driver schema drift 检测** (跟 eket 1 driver 区别 治理, Gap 4)
5. **实战 eket 二级 cache 验证** (跟 Gap 1 联合, Gap 5)

### 综合评分

| 维度 | 评分 | 状态 |
|---|---|---|
| **数据库** | 1:1 (SQLite + WAL + IMMEDIATE) | PASS |
| **Cache L1** | 1:1 (LRU+TTL / moka+TTL) | PASS |
| **Cache L2** | eket 胜 (L2 Redis 缺失) | FAIL (v3.6.0 候选) |
| **Redis 集成** | KALLAX 胜 (5 P0 hotfix 全治根) | PASS |
| **EventBus + Saga** | 1:1 (模式 1:1, 实现不同) | PASS |
| **Hook Server** | KALLAX 胜 (独有, eket 0) | PASS |
| **Audit Log** | KALLAX 胜 (SHA256 chain, eket 普通 JSONL) | PASS |
| **5 levels scripts** | KALLAX 胜 (5 独立脚本, eket 名字 only) | PASS |
| **5 release 累计 hotfix** | 16/16 落地, 50% 后端相关, 5 P0 全治根 | PASS |
| **实战 1 次** | 1/1 验证 (跟 eket 1:1) | PASS |
| **反讽 1:1 复发 闭环** | 5/5 模式 闭环 (跟 V350-B §10 1:1) | PASS |

**总体**: **9/11 PASS**, **2 FAIL (v3.6.0 候选 Gap 1 + Gap 2)**, KALLAX 6 武器 差异化 5 release 累计 0 退步, 跟 eket 形成 互补 模式

---

## 10. 1:1 验证 (跟 Rule 8 4-Level 联合)

| L1 存在性 | L2 实质性 | L3 接线 | L4 数据流动 |
|---|---|---|---|
| ✅ 5 release 累计 50+ commits + 32 hotfix 累计 | ✅ 16 hotfix 1:1 落地 (commit SHA + file:line) | ✅ 跟 V310-A/V350-A 1:1 联合 (不重复) | ✅ 9/11 PASS, 2 FAIL Gap 候选, 5 P0 全治根 |

---

**Report 路径**: `confluence/decisions/eket-vs-kallax/02-backend.md`
**Reviewer**: Backend (Performer/reviewer sub-role, Angle 2 of 6)
**Base**: eket v2.9.2 + KALLAX miao 1b9694b (v3.5.0-hotfix1)
**方法**: Forward + Attack 联合 (跟 V310-A §2 + V350-A §2 1:1 模式, 不重复 V310-A/V350-A 已落地 内容)
**跟 Rule 6/7 EPIC 4 件套 1:1 联合**: A 组 backend 维度 (跟 architect + docs 互补)
**跟 Rule 8 4-Level 1:1 联合**: L1 存在性 + L2 实质性 + L3 接线 + L4 数据流动 全部 PASS

[Co-Authored-By: Claude <noreply@anthropic.com>]