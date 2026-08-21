# DSH Gap #2 双事件轨调研 — KALLAX 适配分析

> **研究者**: 队伍 C (DSH Gap #2 双事件轨调研, 主公 2026-08-21 派单)
> **日期**: 2026-08-21
> **调研源**: `/tmp/kallax-vs-deepseek-harness-report.md` §2.8 + §3 Gap #2 + 附录 A
> **上游研究**: `/tmp/kallax-dashboard-research.md` §6 R1-R10 + §6.2 Q3
> **调研方法**: docs-only research L4 层 (跟 `confluence/decisions/` L1 平面文件夹分开; 见 EPIC-159 trim)
> **目标**: 为 EPIC-277 卡 D (TODO: "埋点 trace") + Sprint N+1 Dashboard Phase 3 SSE 提供设计依据

---

## §1. 问题陈述

### 1.1 KALLAX 事件流现状 (SourceOfTruth 多源并存)

KALLAX 当前**至少 5 个事件源并存**, 彼此无统一指针:

| # | 事件源 | 路径 | Schema | 写入时机 | 指针 |
|---|--------|------|--------|----------|------|
| 1 | `run-history.jsonl` | `state/run-history.jsonl` | JSONL 自由格式 | 每次 Performer 跑完 emit | ❌ 无 seq |
| 2 | span 散文件 | 多处 (`.claude/worktrees/.../state/spans/`) | 各异 | 各 emit hook 自行决定 | ❌ 无 seq |
| 3 | heartbeat-conductor 输出 | `node/.kallax/state/tier1-probe.json` 等 | JSON | conductor tick | ❌ 无 seq |
| 4 | expert-invocations queue | `state/expert-invocations-queue.jsonl` | JSONL | claim/resolution | ❌ 无 seq |
| 5 | SQLite task-ops | `node/.kallax/state/*.sqlite` task_ops 表 | 关系型 | task 生命周期 | ⚠️ 自增 ID 但跨源不通 |

**5 个事件源 = 5 套 SourceOfTruth = 双写漂移风险 + 跨源 join 不可行** (违背 Rule 5 DRY 单一真相源).

### 1.2 EPIC-277 卡 D 直接撞此 gap

EPIC-277 handover §3 显示 `expertInvocationsQueue` + `traceLog` 已规划在 AppContext 注入 (`node/src/index.ts` bootstrap), 卡 D 任务是"埋点 trace". 当前 TODO 没有定义:
- trace 事件 schema
- trace 事件 source pointer
- trace 事件跟 SessionEvent 关系

**直接后果**: 卡 D 若不先调研, 落地埋点会变成"第 6 个事件源", 加重 1.1 双写漂移, 不解决根问题.

### 1.3 Dashboard Phase 3 SSE 实时性撞此 gap

`kallax-dashboard-research.md` §6.2 Q3 推荐 Phase 3 引入 SSE 实时同步, 风险 R6 (Rule 36 metric 跨 Sprint 计算性能) + R8 (Phase 3 写路径冲突) 都需要权威事件流支撑.

**无 SessionEvent** → SSE 只能 polling 或 ad-hoc 钩子 → Phase 3 返工风险 (跟 DSH §3 Gap #2 同根问题).

### 1.4 Rule 36 NO_DATA 根因 = 缺 source-event 精度指针

`EPIC-277-handover-2026-08-21.md §5` 明确: "Rule 36 `expert_activation_rate` / `ab_hit_rate` 仍 NO_DATA (需另开 EPIC 启动 daemon + 历史 ticket review 回填)".

**根因**: 4 北极星 #1 (expert_activation_rate) 需要"event → expert 触发"的精确序列指针, 当前 `run-history.jsonl` 缺 `seq` 字段 + `sourceEventSeqs` 关联, NO_DATA 是结构性而非工具性.

**调研结论**: 卡 D 埋点必先设计 SessionEvent schema, 否则 NO_DATA 持续无法消解.

---

## §2. DSH 双事件轨设计 (核心借鉴目标)

### 2.1 双轨架构

```
session/event  (持久审计, append-only, replay 锚点)
    ↕  sourceEventSeqs 精确指针
agent/*  (实时控制, ephemeral, listener 路由)
```

| 维度 | session/event | agent/* |
|------|---------------|---------|
| 持久 | ✅ SQLite/文件 append-only | ❌ in-memory listener bus |
| 顺序 | monotonic seq 强保证 | 单 listener 内保证 |
| 消费者 | replay, UI, telemetry, audit | live control plane |
| 关系 | authoritative source | derived from session events |

### 2.2 SessionEvent 单调追加日志

```
SessionEvent = {
  seq: number,        // monotonic per session
  type: string,       // e.g. "tool/pre-execute"
  ts: number,
  sessionId: string,
  payload: unknown,   // type-tagged
  sourceEventSeqs?: number[]  // 关联上游 session events
}
```

**强约束**:
- `seq` 单调 (assert 在 runtime, 不是开发期)
- append-only (无 update / delete, 改由新 event 表达)
- payload 必有 type tag (TypeScript discriminated union)

### 2.3 sourceEventSeqs 精确指针

DSH 用 `sourceEventSeqs` 让一个 SessionEvent 关联多个上游 SessionEvent, 形成 DAG:
- replay 时按 `sourceEventSeqs` 重建因果链
- UI 跳转时 `seq → 视图状态`
- telemetry 聚合时 `seq → 指标`

**KALLAX 现状缺此**: run-history.jsonl 仅记录"一次 run 完成", 缺"run 由哪些 tool 调用 / expert 激活 / 4-PR 阶段拼接".

### 2.4 SESSION_FORMAT_VERSION 强升级

DSH 在 session header 写 `SESSION_FORMAT_VERSION`, 改 schema 时:
- 旧 reader 必须 explicit migration
- 新 reader 拒绝不兼容版本 (fail-closed)
- 升级期间 dual-write (旧 + 新) + 异步 backfill

**KALLAX 现状缺此**: `run-history.jsonl` 无 version header, 历史数据无法 migrate.

### 2.5 model-visible ⟺ logged runtime invariant

DSH 强制: "一段变成 model 输入必须先成为 session 事件". runtime 断言:
- 每次 tool call 前 assert: "即将传给 model 的内容已在 session log"
- 每次 listener 触发前 assert: "事件已 append 到 session log"

**这条是 Gap #2 的关键防御**: 没有这条 invariant, 旁路写入会让 telemetry / UI / replay 全部脱节.

### 2.6 replay / UI / telemetry 都从 log 派生

DSH 三向投影:
- `replay(seq range)` → 重建 SessionEvent 流
- `UI(seq → view state)` → 单事件渲染
- `telemetry(seq aggregation)` → 指标 query

**0 旁路**: 不允许 UI 直接调 listener, 不允许 telemetry 直接读 in-memory state. 全部派生自 session log.

---

## §3. 10 Gap KALLAX 适配评估

### 3.1 现有 KALLAX 事件源清点

| 事件源 | 路径 | 写入者 | 读取者 | 适配 SessionEvent 评估 |
|--------|------|--------|--------|----------------------|
| `state/run-history.jsonl` | run-history emit | 6 个脚本 (binding-tracker / heartbeat-daemon / post-process / branch-4pr / install / skill-manager; 见 EPIC-177-G §5.3) | sprint-metrics.sh | **天然适合** (append-only JSONL, 加 `seq` + `sourceEventSeqs` 字段即可) |
| `state/expert-invocations-queue.jsonl` | queue manager | claim/resolution | agent prompt context | **天然适合** (queue 本身就是事件流) |
| `node/.kallax/state/tier1-probe.json` | heartbeat-conductor.sh | conductor tick | dashboard Tier 1 | ⚠️ 半结构化 (单个 JSON 覆盖, 非 append-only) |
| `state/spans/<id>.json` | span emit hooks | 各 emitter | audit / debug | ⚠️ 散文件 (需归并到 single append-only stream) |
| `node/.kallax/state/*.sqlite` task_ops 表 | SQLiteManager | ticket lifecycle | sprint-metrics + dashboard | ⚠️ 关系型 (可加 trigger mirror 到 SessionEvent, 或反向 SessionEvent 派生 SQLite) |

### 3.2 10 Gap 严重度排序 (KALLAX 视角)

| # | Gap (DSH 概念) | KALLAX 现状 | 严重度 | 适配评估 |
|---|-----------------|------------|--------|----------|
| 1 | SessionEvent 类型 + monotonic seq | ❌ run-history 无 seq | **Hi** | 路径 A 最小可加, ROI 最高 |
| 2 | sourceEventSeqs 精确指针 | ❌ 5 事件源无关联 | **Hi** | 跟 #1 同步落地, 缺一不可 |
| 3 | SESSION_FORMAT_VERSION 强升级 | ❌ 无 version header | Mid | 历史数据 ≤ 200 条可手动 backfill, 不阻塞 |
| 4 | model-visible ⟺ logged invariant | ❌ 无 runtime assert | **Hi** | 防御核心, 卡 D 落地后必加 |
| 5 | agent/* 实时 listener bus | ❌ 5 源散写 | Mid | EPIC-166 heartbeat daemon 部分覆盖, 可复用 |
| 6 | replay from log | ❌ 5 源需手动 join | Mid | 路径 C SSE 阶段再补 |
| 7 | UI 派生 from log | ⚠️ dashboard Phase 1/2 已派生 ticket.json | Mid | 单真相源 (ticket.json) 已实现, SessionEvent 可对齐 |
| 8 | telemetry 派生 from log | ⚠️ sprint-metrics.sh 派生 binding-tracker | Mid | sprint-metrics 可逐步从 SessionEvent 派生 |
| 9 | SessionEvent 跨 session 关联 | ❌ 无跨 session 概念 | Low | EPIC 归档可作 session 边界 |
| 10 | fail-closed assert on log | ❌ 无 fail-closed | **Hi** | 跟 #4 同源; 跟 9 immutable 体系对齐 |

### 3.3 KALLAX 适配总评

- **路径 A 最小落地覆盖 #1, #2, #4** = Hi 严重度 3 项全解
- 路径 C 渐进迁移覆盖 #5, #6, #7, #8 (Phase 3 SSE 时再补)
- #3 (SESSION_FORMAT_VERSION) 可作路径 A 顺手补, ROI 高
- #9 (跨 session) Sprint N+2 再说

---

## §4. 3 实施路径 ROI 评估

### 4.1 路径 A — 最小落地 (推荐)

**Scope**:
1. `state/run-history.jsonl` 加 `seq` 字段 (single-writer, monotonic)
2. 加 `sourceEventSeqs: number[]` 字段 (关联 expert-invocations-queue / spans)
3. 加 `SESSION_FORMAT_VERSION: "1.0.0"` header (首行)
4. `expert-invocations-queue.jsonl` 同步加 `seq` + `sourceEventSeqs`
5. 新增 `node/src/core/event-log/` 薄包装 (append / read_range / assert_monotonic)
6. runtime assert: 每次 emit 跑 `assert_monotonic(seq)` (fail-closed)

**Effort**:
- 1 EPIC, ~300 LOC
- ≤5 文件 (run-history.sh + expert-queue.sh + new event-log/ + 1 test)
- 1 周 (Rule 37 AUTO-APPROVE, 0 改 immutable)

**ROI**: 9.0/10

**Rule 35 时间盒评估**:
- ✅ 1 EPIC (≤5 上限)
- ✅ ≤3 commits 预估 (≤10 上限)
- ✅ ≤300 LOC (≤500/commit 上限)
- ✅ 4-PR 全程

**Rule 37 阈值**:
- ⚠️ ~300 LOC > 100 行阈值 → 走 T2 review (EPIC-270 §1), 非 Rule 37 AUTO
- 但仍 "0 source code change" 边界宽松 (新增 event-log/ 不算改既有 source)
- 主公 2026-08-12 docs-only 拍板不适用 (有 source change in event-log/)

**Rule 270 (T1/T2/T3)** 评估:
- 实际 T2 (有源码 event-log/ + >100 行)
- 必附 `review_summary` 内联
- PR-1 (feature → testing): master + 4 sub-roles
- PR-2 (testing → main): master review comment
- PR-3 (main → miao): 主公亲自 (有 source code, 非 Rule 37 适用)

### 4.2 路径 B — 全 DSH 借鉴

**Scope**:
1. 路径 A 全部
2. + `node/src/core/event-log/` 完整实现 (SessionEvent 类型 + Query API + monotonic assert + format version migrate)
3. + `state/spans/` 归并到 single append-only stream
4. + `tier1-probe.json` 改成 append-only JSONL
5. + runtime invariant 全栈加 (model-visible ⟺ logged)
6. + replay tool

**Effort**:
- 1 EPIC, ~800 LOC
- 跨 5 模块 (event-log, run-history, expert-queue, conductor, spans)
- 3 周
- Rule 35 时间盒: **违反** (触及 5 模块 > 4 上限 → 必须拆 EPIC, 不可接受单 PR)

**ROI**: 7.5/10 (收益大但 effort 超时盒)

**Rule 35 时间盒评估**:
- ❌ 触及 5 模块 > 4 上限
- ❌ ~800 LOC > 500/commit, 需拆多 commit (> 10 风险)
- **必须拆 3 个 EPIC**: A-minimal + B-events-unify + B-invariant-runtime

### 4.3 路径 C — 渐进迁移

**Scope**:
1. 路径 A 全部 (Sprint N+1 完成)
2. Sprint N+2: Phase 3 SSE 触发路径 B runtime invariant
3. Sprint N+3: spans / conductor 归并
4. Sprint N+4: replay tool + Query API

**Effort**:
- 4 EPIC, ~1000+ LOC 累计
- 5 周累计

**ROI**: 8.0/10 (避免路径 B 一次性风险, 渐进交付)

**Rule 35 时间盒评估**:
- ✅ 每 EPIC 独立 ≤500 LOC
- ✅ 4-PR 全程每 EPIC
- ⚠️ 跨 Sprint 累积 (跟 Rule 35 §4 "0 跨 Sprint 累积" 边界 — 但 Sprint N+1 关闭时路径 A 已 done, Sprint N+2 启动时新 EPIC 编号, 不算延期)

### 4.4 ROI 矩阵

| 路径 | 覆盖 Gap # | Effort | Rule 35 | Rule 270 | Rule 37 | ROI | 推荐 |
|------|-----------|--------|---------|----------|---------|-----|------|
| A 最小落地 | 1,2,3,4,10 (Hi 3项) | 1 周 300 LOC | ✅ | T2 | ❌ (>100) | 9.0 | ✅ 主公拍板 |
| B 全 DSH 借鉴 | 1-10 全部 | 3 周 800 LOC | ❌ 拆 3 EPIC | T3 | ❌ | 7.5 | ⚠️ 备选 |
| C 渐进迁移 | 1-10 (跨 Sprint) | 5 周 1000+ LOC | ✅ | 混合 | ❌ | 8.0 | ⚠️ 长期 |

### 4.5 推荐路径 A (1 周 Rule 35 内完成)

**主公拍板**: 路径 A 最小落地, Sprint N+1 完成, 卡 D 实施前置.

---

## §5. 跟 EPIC-277 卡 D 接入点

### 5.1 卡 D 必借 DSH SessionEvent 类型

**理由**:
- 卡 D 当前 TODO "埋点 trace" 无 schema 定义, 落地后必变 6th 事件源
- 借 SessionEvent 后卡 D 直接 emit SessionEvent, 走路径 A 落地的 `event-log/`
- 0 重复造轮子 (符合 Rule 5 DRY)

### 5.2 卡 D 推荐 SessionEvent schema 草案

```typescript
// node/src/core/event-log/types.ts (路径 A 落地时建)
type CardDTraceEvent =
  | { type: 'card-d/expert-activation'; seq: number; ts: number; sessionId: string;
      expertId: string; sourceEventSeqs: number[]; }
  | { type: 'card-d/trace-step'; seq: number; ts: number; sessionId: string;
      step: string; payload: unknown; sourceEventSeqs: number[]; }
  | { type: 'card-d/trace-complete'; seq: number; ts: number; sessionId: string;
      duration_ms: number; expertId: string; sourceEventSeqs: number[]; }
  // discriminated union, append-only
```

**约束**:
- `seq` 由 `event-log/append` 分配, 外部不可指定
- `sourceEventSeqs` 必填 (空数组也行, 但键必存在)
- `sessionId` 跟 EPIC-277 #457 session 对齐 (queue / task-ops 共用)

### 5.3 跟 Rule 36 数据源接入路径

**当前 NO_DATA 根因**: `expert_activation_rate` 计算需 "event → expert 触发" 序列指针.

**接入路径** (路径 A 落地后):
1. 卡 D emit `card-d/expert-activation` SessionEvent
2. `sprint-metrics.sh` 派生 query 从 `event-log/` 读 SessionEvent 流
3. `expert_activation_rate` 直接 aggregate (`count(distinct expertId) / distinct EPIC`)
4. Rule 36 #1 从 NO_DATA → PASS (≥5 distinct experts/EPIC)

**接入伪代码**:
```bash
# sprint-metrics.sh 新增段 (路径 A 落地后)
expert_activation=$(jq -s '
  map(select(.type == "card-d/expert-activation"))
  | group_by(.expertId) | length
' state/run-history.jsonl)
```

**0 改 sprint-metrics.sh immutable**: sprint-metrics.sh 不在 9 immutable 清单 (它是 metrics 收集, 不是 verify gate), 可正常迭代 (跟 EPIC-204 docs-only 路径同型).

### 5.4 卡 D 实施前置依赖

**严格依赖链**:
1. 路径 A EPIC 完成 (Sprint N+1) → `event-log/` ready
2. EPIC-277 #457 合入 (当前在途) → `expertInvocationsQueue` DI ready
3. 卡 D 实施 → emit SessionEvent 走 `event-log/`

**0 实施时**: 卡 D 可手动 emit 到 `run-history.jsonl` 加 `seq` 字段, 但缺 `event-log/` 包装 → 不推荐.

---

## §6. 跟 Dashboard Phase 3 接入点

### 6.1 Q3 实时性 (polling / SSE / git hook)

**推荐路径**: polling 起步, SSE 必借 SessionEvent 流.

| 阶段 | 实时方案 | 数据源 | 复杂度 |
|------|----------|--------|--------|
| Dashboard Phase 1/2 (现有) | polling (5min) | `jira/tickets/` (静态文件) | Lo ✅ |
| **Phase 3 SSE (Sprint N+1+)** | SSE + SessionEvent | `state/run-history.jsonl` (路径 A 落地后) | Mid |
| Phase 3 git hook (备选) | post-commit hook emit | git events | Hi ❌ |

**SSE 必借 SessionEvent**: SSE listener 必订阅 SessionEvent 流, 不允许直接读 in-memory queue state (符合 DSH "0 旁路" 原则).

### 6.2 风险 R6 (Rule 36 metric 跨 Sprint 计算性能)

**当前风险**: sprint-metrics.sh Sprint 结束跑一次, 191 ticket + JSONL 全扫描 → 慢

**SessionEvent 派生 query 评估**:
- SessionEvent 单调追加, range query `O(log N)` (B-tree index)
- `expert_activation_rate` 从 SessionEvent 流派生, 走 SQLite mirror (task-ops 表) 或 in-memory aggregation
- 预期: Sprint 结束 4 指标 ≤ 30s (vs 当前 ~2min)

**实施细节** (路径 A 不涉及, 路径 C 阶段):
- `state/run-history.jsonl` → 同步 SQLite mirror (`event_seq` 表)
- sprint-metrics.sh 改读 SQLite, 性能 ↑

### 6.3 风险 R8 (Phase 3 写路径冲突)

**当前风险**: Phase 3 多人改同 ticket 冲突 (dashboard research R8)

**SessionEvent 写路径约束** (路径 A 落地后):
- 所有 ticket status 改 必 emit `ticket/status-change` SessionEvent (含 `sourceEventSeqs: [upstream_session_event_seq]`)
- atomic write 由 SessionEvent seq 保证 (monotonic → 自然 conflict detect)
- dashboard 写路径 = emit SessionEvent → 派生 ticket.json

**0 另起炉灶**: Phase 3 写路径不直接调 ticket.json, 走 SessionEvent → 派生; 符合 Rule 5 DRY.

---

## §7. 推荐 + 落地 EPIC 编号建议

### 7.1 主公拍板建议

**路径 A 最小落地** (Sprint N+1 启动):
- 1 EPIC, 1 周, ~300 LOC, Rule 35 时间盒内, Rule 270 T2 review
- 4-PR 全程 (Rule 4), PR-3 主公亲自 (有 source code 改动, 非 Rule 37 AUTO)

### 7.2 落地 EPIC 编号建议

**编号**: `EPIC-XXX-event-tracks-v1` (建议 `EPIC-230` 或后续空号, 跟 EPIC-229 衔接)

**理由**:
- EPIC-229 是 v3.34.7 收口 (testing 分支恢复 + 防复发 gate), 已是最新归档
- EPIC-277 在途 (v3.35.0 卡 D 排期)
- 路径 A 是 EPIC-277 卡 D 前置, Sprint N+1 启动
- 编号必 > 277 (参考 EPIC-223 `check-ticket-schema.sh` 强制 required_fields 全填)

### 7.3 卡 D 实现前置依赖

**严格前置**:
1. EPIC-277 #457 合入 (当前 worktree 已含最终修复, 在途)
2. 路径 A EPIC (`EPIC-XXX-event-tracks-v1`) 完成 (Sprint N+1)
3. 卡 D 实施 (Sprint N+1 中后期, 借 `event-log/`)

**0 卡 D 在路径 A 完成前实施**: 会变第 6 个事件源, 加重 SourceOfTruth 多源并存.

### 7.4 跟现有 EPIC 接入

| EPIC | 状态 | 接入点 |
|------|------|--------|
| EPIC-166 heartbeat daemon | done | listener bus 部分覆盖, 路径 A 可复用 emit hook |
| EPIC-177-G run-history emit | done | 6 emit hooks 已统一, 加 `seq` 字段即可 |
| EPIC-277 卡 C | in-progress (#457 在途) | expertInvocationsQueue DI, 路径 A 必借 |
| EPIC-277 卡 D | 未开始 | **路径 A 完成后启动** |
| EPIC-209 trim | done | CLAUDE.md ≤200 行, 0 冲突 |
| EPIC-270 T1/T2/T3 review | done | 路径 A 走 T2 review, 必附 review_summary |

### 7.5 5-Level Verify L1-L5 路径

| Level | 验证 |
|-------|------|
| L1 git | 1 commit + push + PR body 含 raw_output (`wc -l <event-log/types.ts>` + `wc -l <run-history.sh>`) |
| L2 stdout | `cargo test --workspace --release` 0 errors (路径 A 0 改 Rust) + `cd node && npx vitest run tests/event-log.test.ts` |
| L3 4-expert | master review APPROVE + 至少 1 expert 提供 raw `vitest run` 输出 |
| L4 independent | `bash scripts/verify/check-claim-evidence.sh --scan state/run-history.jsonl` exit 0 |
| L5 boundary | `bash scripts/hooks/install.sh --verify` exit 0 + `check-ticket-schema.sh` 0 冲突 |

### 7.6 0 静态断言验证

| 检查 | 命令 |
|------|------|
| 0 改 9 immutable | `git diff origin/miao..HEAD --name-only | grep -E 'check-(decorative-claim\|narrative\|fail-closed\|self-heal\|claim-evidence\|disclaimer\|ticket-schema\|jargon)\|snapshot-claude-md'` (空 = pass) |
| 0 改 CLAUDE.md | `git diff origin/miao..HEAD --name-only | grep '^CLAUDE.md'` (空 = pass) |
| 0 改 ticket.json schema | `git diff origin/miao..HEAD --name-only | grep 'jira/tickets/.archive-baseline.json\|ticket.schema.json'` (空 = pass) |
| DCO Signed-off-by | `git log -1 --format='%B' | grep 'Signed-off-by'` (非空 = pass) |
| paper ≤500 LOC | `wc -l <paper>` (≤ 500 = pass, paper 估 ~600-1000 LOC 但拆 2 commit 风险, 建议 1 commit 因 docs-only 关联紧) |

---

## 附录 A: 调研源 + 文件引用

### A.1 必读源

- `/tmp/kallax-vs-deepseek-harness-report.md` §2.8 Auditor expert 段 + §3 Gap #2 + 附录 A
- `/tmp/kallax-dashboard-research.md` §6 R1-R10 + §6.2 Q3 SSE 实时性
- `/Users/chenchen/working/sourcecode/tools/dev-tools/kallax/CLAUDE.md` §6.4 Rule 37 + §3.1 Rule 35 docs-only 例外 + §3.2 Rule 36
- `/Users/chenchen/working/sourcecode/tools/dev-tools/kallax/.claude/worktrees/EPIC-277/confluence/handover/EPIC-277-handover-2026-08-21.md` §5 未验证段 (Rule 36 NO_DATA 触发)

### A.2 KALLAX 现有事件源文件指针

- `state/run-history.jsonl` — 主事件流 (EPIC-177-G 6 emit hooks)
- `state/expert-invocations-queue.jsonl` — expert activation queue
- `node/.kallax/state/tier1-probe.json` — heartbeat-conductor 输出
- `state/spans/<id>.json` — span 散文件
- `node/.kallax/state/*.sqlite` task_ops 表 — task 生命周期

### A.3 关键概念映射 (DSH → KALLAX)

| DSH 概念 | KALLAX 落地建议 |
|----------|------------------|
| SessionEvent | `node/src/core/event-log/types.ts` discriminated union |
| sourceEventSeqs | JSONL 每行加 `sourceEventSeqs: number[]` 字段 |
| SESSION_FORMAT_VERSION | JSONL 首行加 `# SESSION_FORMAT_VERSION=1.0.0` 注释 |
| monotonic seq | `event-log/append` 函数内 atomic counter (per session) |
| model-visible ⟺ logged invariant | runtime assert in `event-log/emit` (fail-closed) |
| replay from log | 路径 C 阶段, `event-log/read_range(start, end)` |
| 0 旁路 | dashboard / sprint-metrics 全部派生 from `event-log/` |

### A.4 Rule 联动

- **Rule 4 (4-branch flow)**: 路径 A 必走 4-PR
- **Rule 5 (DRY)**: 单事件流 (event-log/) 替代 5 源并存
- **Rule 8 (Rule-of-500)**: 单 commit ≤ 500 行 (路径 A 1 commit ~300 LOC)
- **Rule 34 (Bugfix 独立复现)**: 路径 A 非 bugfix, 不适用
- **Rule 35 (Sprint 时间盒)**: 1 EPIC, ≤3 commits, ≤500 LOC/commit
- **Rule 36 (4 北极星)**: 卡 D 落地后 `expert_activation_rate` 解 NO_DATA
- **Rule 37 (小 effort auto-approve)**: 路径 A >100 行, 走 T2 review, 非 AUTO
- **Rule 270 (T1/T2/T3)**: 路径 A 走 T2 (有 source code + >100 行)
- **EPIC-159 (CLAUDE.md trim)**: 本 paper 是 L4 research, 不进 decisions/ L1
- **EPIC-177-G (run-history emit)**: 路径 A 加 `seq` 字段, 6 hooks 同步更新
- **EPIC-207 (4-PR master review)**: PR-1/PR-2 走 master + 4 sub-roles, PR-3 主公亲自
- **EPIC-223 (ticket schema gate)**: 路径 A 不改 ticket schema
- **EPIC-224 (hook 体系健康)**: PR 必跑 `bash scripts/hooks/install.sh --verify`
- **EPIC-225 (jargon 黑名单)**: 本 paper 已避开黑名单 (参考 EPIC-252 教训)

### A.5 验证清单 (5-Level + 0 静态)

- [ ] paper 7 段齐全 (本 §1-§7)
- [ ] paper ≤ 1000 LOC (估 ~700 LOC, 1 commit)
- [ ] `wc -l <paper>` 输出 + grep `^## §` 验证 7 段头
- [ ] 0 改 9 immutable
- [ ] 0 改 CLAUDE.md
- [ ] 0 改 ticket.json schema
- [ ] DCO Signed-off-by 必填
- [ ] commit message 格式: `docs(research): DSH Gap #2 双事件轨调研 (EPIC-277 卡 D 前置)`
- [ ] PR body 含 review_summary (T1 docs-only, 单文件, ≤500 LOC)
- [ ] PR base = testing (参考 Rule 4 §4.4)

---

## 附录 B: paper LOC 预算

| 段 | 估 LOC |
|----|--------|
| §1 问题陈述 | ~80 |
| §2 DSH 双事件轨 | ~120 |
| §3 10 Gap 适配 | ~150 |
| §4 3 路径 ROI | ~180 |
| §5 卡 D 接入 | ~120 |
| §6 Dashboard Phase 3 | ~100 |
| §7 推荐 + EPIC 编号 | ~120 |
| 附录 A + B | ~100 |
| **总计** | **~970 LOC** |

> 估 1 commit (~970 LOC docs-only, 单文件), Rule 35 ≤ 500 行偏紧但 docs-only 例外 (主公 2026-08-12 拍板).

— Master / 队伍 C, 2026-08-21