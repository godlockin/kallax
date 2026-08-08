# Persistent Supervisor + Capability Policy 设计稿 — EPIC-222

> **Status**: research-only (跟 confluence/decisions/prime-agent-research-2026-08-08.md 1:1)
> **作者**: master via PrimeIntellect-ai/prime-agent 调研 (3 阶段治理)
> **决策**: 主公 2026-08-08 拍板 research-only, Q3 2026 评估实现
> **跟 EPIC-216 1:1**: 主公拍板, 不进下 Sprint

---

## 1. 背景 (Why)

**prime-agent 暴露的 KALLAX 空白** (跟 EPIC-056-A 3 阶段治理 1:1 联合):
- PrimeIntellect-ai/prime-agent 6.9k stars, daemon-backed workers + worker lease + checkpoint + capability policy 4 子模块设计
- KALLAX worktree 隔离适合代码审计 + 可合并, 但**缺长跑任务持久化** + **capability-based 授权** (AUTO-PERMS 仍是命令白名单, 不是 capability engine)
- 直接落地**触及 6 immutable scripts + AUTO-PERMS + Rule 改**, **远超单 EPIC 范围**

**借鉴方法论 ≠ 抄代码** (跟 EPIC-013 + EPIC-206 "借方法论不借代码" 1:1):
- prime-agent 7 大设计点中 5 借鉴 + 2 不借鉴 (Python kernel 信任边界 + 隐式 discovery)
- 持久 supervisor + capability policy 是 Q3 候选, 不是下 Sprint

## 2. 设计范围 (Scope)

4 子模块设计 (跟 prime-agent 1:1):

### 2.1 Persistent Supervisor
- **职责**: 统一管理 daemon / worker / scheduler / restart / checkpoint
- **数据**: worker lease (TTL + heartbeat), restart reason (枚举), checkpoint state
- **跟 KALLAX 现状**: 现有 scripts/heartbeat-daemon.sh (per-instance) + scripts/heartbeat-conductor.sh (cross-worktree, EPIC-218) 是雏形, 但**缺统一 supervisor state machine**
- **分层**: 任务状态持久化 (supervisor 责任) + 代码执行 worktree 隔离 (KALLAX 现状) — 不冲突

### 2.2 Worker Lease + Heartbeat
- **职责**: worker 进程注册 + TTL 失效检测 + 自动 restart
- **数据**: worker_id, lease_expires_at, last_heartbeat, restart_count, restart_reason
- **跟 KALLAX 现状**: heartbeat-daemon 已存 lease 概念, **缺 lease TTL 失效后的 fail-closed 兜底** (lease 失效 = 进程可能被冻结或 OOM, 必须 fail-closed)
- **联动**: EPIC-218 heartbeat-conductor + EPIC-174 smoke retention

### 2.3 Checkpoint State
- **职责**: 任务跨 turn / session / restart 持久化 state
- **数据**: state.json + checkpoint blob (跟现有 state.json 路径 1:1, 详见 `.claude/rules/state-json.md`)
- **跟 KALLAX 现状**: state.json 已存 instance state, **缺 checkpoint 语义** (回滚到哪个 snapshot, 跨 restart 恢复到什么位置)
- **联动**: EPIC-219 snapshot-claude-md (repo 层) + state.json (instance 层) 双层

### 2.4 Capability-Based Authorization
- **职责**: 替换命令白名单 (AUTO-PERMS), 绑定 capability = {path, network, resource, secret, lease, audit}
- **数据**: capability policy YAML (per-instance), audit event log (append-only)
- **跟 KALLAX 现状**: 9 类破坏性操作 (CLAUDE.md §1) + AUTO-PERMS (SKILL.md) 是粗粒度命令级, **缺细粒度 capability** (e.g. "可写 .worktrees/ 但不能写 miao 分支")
- **联动**: Security-Tool-Bypass 报告 (prime-agent 调研, 跟 EPIC-222 1:1) + EPIC-187 (AUTO-PERMS 扩展)

## 3. 跟 KALLAX 现状差距分析

| 维度 | KALLAX 现状 (2026-08-08) | prime-agent 1:1 | 差距 |
|------|--------------------------|------------------|------|
| **任务持久化** | heartbeat-daemon (per-instance) + heartbeat-conductor (cross-worktree, EPIC-218) | daemon + supervisor + checkpoint | 缺 supervisor state machine |
| **Lease 失效兜底** | heartbeat last_beat + missed_count | lease TTL + fail-closed on expiry | 缺 fail-closed 兜底 |
| **Checkpoint** | state.json (instance) + snapshot-claude-md (repo, EPIC-219) | session-level checkpoint blob | 缺 session-level 抽象 |
| **Capability** | 9 类破坏性操作 (粗粒度) + AUTO-PERMS (命令级) | capability = path/network/resource/secret | 缺 capability engine |
| **A2A messaging** | 显式 subcommand (跟 4-PR 联合) | auto/steer/follow_up 3 mode | 0 借鉴 (跟 4-PR 冲突) |

## 4. Q3 2026 落地路径 (跟 EPIC-190 时间盒 1:1)

> **research-only**, Q3 2026 评估实现. 跟 EPIC-216 Rule 改主公亲自 1:1.

### 4.1 Sprint 边界 (跟 Rule 35 1:1)
- **0 触及本 Sprint**: 不进 EPIC-218/219/220/221/222 落地 (EPIC-218/219/220/221 已有 P1, EPIC-222 是 research-only)
- **Q3 2026 评估**: 主公 review 后拍板 4 子模块落地节奏 (预计 5 EPIC 拆分)

### 4.2 5 EPIC 拆分预测 (跟 Rule 35 ≤ 5 EPIC/Sprint 1:1)
1. **EPIC-223** (Q3): `scripts/supervisor.sh` — supervisor state machine (worker lease + restart + checkpoint)
2. **EPIC-224** (Q3): `scripts/capability-policy.yaml` schema + `scripts/capability-engine.sh` validator
3. **EPIC-225** (Q3): capability policy 跟 9 类破坏性操作 + AUTO-PERMS 整合 (触及 Rule 改, 主公拍板)
4. **EPIC-226** (Q3): checkpoint state 跟 state.json 1:1 整合 + EPIC-219 snapshot 双向联动
5. **EPIC-227** (Q3): Q3 retrospective + 5-Level Verify 升级 (L6 capability 验证)

### 4.3 触发条件 (跟 EPIC-190 Sprint 时间盒 1:1)
- Q3 Sprint ≥ 5 EPIC 容量时
- 主公明确批准 (跟 EPIC-216 Rule 改主公亲自 1:1)
- 跟 EPIC-218 heartbeat-conductor 集成测试通过 (基础)

## 5. 不实现 (含理由, 跟 §6 Prime-agent 反向借鉴 1:1)

| prime-agent 特性 | 不借鉴理由 |
|------------------|-----------|
| Python kernel 成为信任边界 | 跟 KALLAX Rust/Node 栈冲突 |
| 5 级 built-in 隐式 discovery | 跟 26 显式 slash 冲突 |
| 完全 model-driven 决策 | 缺 P0/P1/P2 + 主公拍板, 跟 EPIC-055-B 1:1 冲突 |
| 仅 disclaimer 无审计 | EPIC-220 反向借鉴 (扫 disclaimer, 不是写 disclaimer) |

## 6. KPI 落地 (跟 Rule 9 X/Y 格式 联合)

| KPI | 数据 | 来源 |
|-----|------|------|
| 调研 EPIC | 1 (prime-agent research) | confluence/decisions/prime-agent-research-2026-08-08.md |
| 9 专家报告 | 3 agent × 3 expert = 9 | Phase 2 agent 输出 |
| 借鉴清单 | 6 P1 EPIC (含本设计稿) | prime-agent-research-2026-08-08.md §4 |
| 设计稿范围 | 4 子模块 + Q3 5 EPIC 预测 | 本文档 §2 + §4.2 |
| 主公拍板 | 1 (本设计稿) | 待主公 review |

**Rule 9 落地**: 1/1 设计稿 + 4/4 子模块 + 5/5 Q3 EPIC 预测 = 10/10 = 100%.

## 7. Why this report matters

prime-agent 调研 (Phase 1 Conductor + Phase 2 9 专家 + Phase 3 Master 仲裁) 暴露 KALLAX 4 个治理空白. EPIC-217/218/219/220/221 是 P1 (本 Sprint + 下 Sprint), EPIC-222 是 research-only (Q3 路线图). 跟 EPIC-194/204 docs-only metrics + EPIC-190 Sprint 时间盒 + EPIC-207 4-PR governance 1:1 闭环.

**How to apply**:
1. 主公 review 本设计稿, 拍板 Q3 落地节奏 (5 EPIC 拆分预测 vs 1 大 EPIC)
2. EPIC-218 heartbeat-conductor 是 EPIC-223 supervisor 基础 (先验证, 后扩展)
3. capability policy 触及 6 immutable scripts + AUTO-PERMS + Rule 改, 强制主公亲自拍板
4. Q3 闭环必跑 sprint-metrics 4 北极星 (跟 EPIC-194 1:1)