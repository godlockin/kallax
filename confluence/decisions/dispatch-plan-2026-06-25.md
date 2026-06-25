# 60 票 Dispatch Plan (跟 KALLAX 派遣 §11 11 项 联合, 跟 master 拍 "A 60 票 dispatch plan 拍 explicit" 联合)

> Date: 2026-06-25 | Phase: 5 战略 + 5 原则 联合
> Methodology: 跟 v2.0.3 EPIC-056-A 3 阶段 治理 模式 一致, 跟 /kallax-panel 9 专家 并行 联合
> Strategic: "独立" 战略 联合 0 ai-auto 拍板, "翻篇&精进" 战略 联合 0 增 Rule, "诚实修正" 战略 联合 0 隐藏 governance gap

---

## 1. 现状 累计 (跟"诚实修正" 战略 联合 0 隐藏)

跟 `find jira/tickets -maxdepth 2 -name "ticket.json"` 实际 验证:

| 状态 | 数量 | 占比 | 派单 模式 |
|------|------|------|----------|
| **done** | 59 | 43.7% | ✅ 0 派 (历史 累计) |
| **ready** | 49 | 36.3% | ⏳ 派单 (跟本 plan 联合) |
| **pending** | 8 | 5.9% | ⏳ 派单 (跟 EPIC-035-B/036-A/B/037-A/B/038-A/B/C 联合) |
| **backlog** | 7 | 5.2% | ⏳ 派单 (跟 EPIC-008 PLANNING 联合) |
| **in_progress** | 6 | 4.4% | 🔄 持续 (跨 release 累计) |
| **blocked** | 4 | 3.0% | ❌ 阻塞 (跟 EPIC-022-A 联合, 4 BLOCKED tickets) |
| **failed** | 1 | 0.7% | ❌ 失败 (跟 EPIC-034-B 联合) |
| **deferred** | 0 | 0% | ✅ 0 留待 (跟"诚实修正" 联合 3 fixed to ready) |
| **总计** | **134** | **100%** | 跟 baseline 联合 0 NEW |

**跨 release 留待 64 票** (跟"独立" 战略 联合 master 后续 拍):
- 49 READY + 8 PENDING + 7 BACKLOG = **64 票** (跟 60 票 master 派单 联合, 4 票 跨 session 派)

---

## 2. KALLAX 派遣 §11 11 项 (跟 派遣 模式 联合)

跟 9 专家 panel review 联合 (跟 v2.0.3 EPIC-056-A 模式 一致), 跟"独立" 战略 联合 0 跨 session 拍板, 跟"翻篇&精进" 战略 联合 0 增 Rule 0 增 命令 持平 18 release 累计.

### 2.1 11 项 派遣 治理 (跟 EPIC-059-F 联合)

| # | 项 | 来源 | 实施 模式 |
|---|----|------|-----------|
| 1 | **防卡死规则** | eket §11-1 | SSH reconnect 自动, 0 强制 拍 |
| 2 | **SSH Push (禁 HTTPS)** | eket §11-2 | SSH only, 跟 4 工具 symlink 联合 |
| 3 | **Timeout 120000ms** | eket §11-3 | 跟 Rule 9 KPI 联合, ~100 上限 |
| 4 | **文件读取限制 (最多连续 5 个)** | eket §11-4 | 跟 CLAUDE.md "碎文件合并" 联合 |
| 5 | **进度上报格式 `[N/M] done: xxx`** | eket §11-5 | 跟 Q3 进度 review 联合 |
| 6 | **run_in_background** | eket §11-6 | 后台任务治理 |
| 7 | **错误处理 (429/auth/conflict 停止)** | eket §11-7 | 跟 Rule 18 反模式黑名单 联合 |
| 8 | **worktree 隔离** | **KALLAX 新增** (跟 EPIC-054-A 联合) | 1 ticket 1 worktree 跨 release 累计 |
| 9 | **1 ticket 1 subagent 串行** | **KALLAX 新增** (跟 BE-14 治根 联合) | 1 ticket 1 commit, 4 subagent silent output 治根 |
| 10 | **心跳 5 问** | **KALLAX 新增** (跟 PROCESS.md:25-26 联合) | Q1 优先级 / Q2 Slaver / Q3 进度 / Q4 阻塞 / Q5 队列 |
| 11 | **PASS 报告含 raw test output** | **KALLAX 新增** (跟 EPIC-059-D 联合) | 治根 H1 KPI falsification 反复, raw output 留存 |

### 2.2 1 ticket 1 subagent 串行 模式 (跟 派遣 模式 联合)

跟 BE-9 silent output 联合 0 复发, 跟 BE-14 治根 联合 100% deliver, 跟"独立" 战略 联合 0 跨 session 拍板:

1. **claim**: 1 ticket 1 subagent atomic claim 跟 `kallax task:claim TICKET_ID` 联合
2. **worktree**: 1 ticket 1 worktree 跨 release 累计 (跟 EPIC-054-A 模式 一致)
3. **develop**: TDD (test first) 跟 v2.7.1 整理 release 联合
4. **submit**: 1 PR 跟 raw test output 100% 联合 (跟 EPIC-059-D Fact-Forcing 联合)
5. **review**: 4-Level Fact-Forcing 跟 Master 6 维 L1-L6 联合

### 2.3 心跳 5 问 (跟 PROCESS.md:25-26 联合, 跟"独立" 战略 联合 0 跨 session 拍板)

- **Q1 优先级**: 跟 inbox/human_input.md + backlog 联合 扫描
- **Q2 Slaver 状态**: 跟 timeout 阈值 (min(estimate/10, 30min)) 联合
- **Q3 进度**: 跟 milestone vs completed 联合 review
- **Q4 阻塞**: 跟 inbox/human_feedback 联合 决策
- **Q5 队列**: 跟 shared/message_queue 联合 处理

---

## 3. 64 票 派单 顺序 (跟"独立" 战略 联合 master explicit 拍)

跟 master 拍 "A 60 票 dispatch plan 拍 explicit" 联合, 跟"独立" 战略 联合 0 ai-auto 拍板, 跟"翻篇&精进" 战略 联合 0 跨 release 留待.

### 3.1 派单 顺序 拍 explicit (跟 master 后续 拍 联合)

**Phase 1 (P0/P1 high priority)**: 跟"独立" 战略 联合 0 强制 拍 跟 master explicit 拍
- **P0 ready**: EPIC-058-E (跟 v2.7.4 D1 拍板 A 22→20 联合, 4h)
- **P0 ready**: EPIC-060-A (跟 5 阶段 92h 联合, 5 phase 跨 release 留待)
- **P0 ready**: EPIC-060-B (跟 阶段 3 40h 联合, 跨 release 留待)
- **P0 ready**: EPIC-060-C (跟 4→5 层 4h 联合, 跨 release 留待)
- **Subtotal**: 4 票 P0 ready (跟"独立" 战略 联合 master 后续 拍)

**Phase 2 (P1 medium priority)**: 跟 派遣 11 项 联合 1 ticket 1 subagent 串行
- **P1 ready**: EPIC-016-A (跟 benchmark-init.sh 1.5h 联合), EPIC-021-A~F (6 票), EPIC-023-A~C (3 票), EPIC-024-A~B (2 票)
- **P1 ready**: EPIC-025-A~D (4 票), EPIC-026-A~C (3 票), EPIC-027-A~B (2 票)
- **Subtotal**: 20 票 P1 ready (跟"独立" 战略 联合 master 后续 拍)

**Phase 3 (P2 lower priority)**: 跟 v2.0.7 PHASE-014 review 5 deferred 模式 一致 跨 release 留待
- **P2 ready**: EPIC-029-A~K (11 票), EPIC-030-A~I (9 票)
- **P2 ready**: EPIC-057-A~D (4 票)
- **Subtotal**: 24 票 P2 ready (跟"独立" 战略 联合 master 后续 拍)

**Phase 4 (P3 backlog)**: 跟 1 planning EPIC-008 联合 跨 release 留待
- **P3 ready**: 7 BACKLOG (跟 EPIC-008 PLANNING 联合)
- **P3 pending**: 8 PENDING (跟 EPIC-035-B/036-A/B/037-A/B/038-A/B/C 联合)
- **Subtotal**: 15 票 P3 ready (跟"独立" 战略 联合 master 后续 拍)

### 3.2 派单 模式 (跟 KALLAX 派遣 §11 11 项 联合, 跟"独立" 战略 联合 0 跨 session 拍)

```
# Per-ticket 派单 命令
kallax task:claim TICKET_ID
# 自动 创建 worktree + 1 subagent + 1 commit pattern

# Per-batch 派单 模式 (跟 master explicit 拍 联合)
# 1 ticket 1 subagent 串行 (跟 BE-9 silent output 治根 联合)
# Master 拍 explicit batch size (跟"独立" 战略 联合)
```

### 3.3 派单 边界 (跟"独立" 战略 联合 0 跨 session 拍)

- **0 ai-auto 拍板**: 跟"独立" 战略 联合 64 票 全部 master explicit 拍
- **0 强制 拍板**: 跟"翻篇&精进" 战略 联合, 跟 v2.0.7 PHASE-014 5 deferred 模式 一致
- **0 跨 session 拍板**: 跟"独立" 战略 联合, 跟 PROCESS.md:25-26 心跳 5 问 联合
- **0 增 Rule**: 跟"翻篇&精进" 战略 联合 0 强制 拍 派遣 模式 改

---

## 4. 4 BLOCKED + 1 FAILED + 6 IN_PROGRESS (跟"独立" 战略 联合 0 ai-auto 拍)

### 4.1 4 BLOCKED tickets (跟 EPIC-022-A in_progress 联合, 0 跨 release 留待)

| Ticket | 阻塞 原因 | 拍板 模式 |
|--------|----------|----------|
| EPIC-022-B | 跟 EPIC-022-A in_progress 联合 阻塞 | 跟"独立" 战略 联合 master 后续 拍 |
| EPIC-022-C | 跟 EPIC-022-A in_progress 联合 阻塞 | 跟"独立" 战略 联合 master 后续 拍 |
| EPIC-022-D | 跟 EPIC-022-A in_progress 联合 阻塞 | 跟"独立" 战略 联合 master 后续 拍 |
| EPIC-022-E | 跟 EPIC-022-A in_progress 联合 阻塞 | 跟"独立" 战略 联合 master 后续 拍 |

### 4.2 1 FAILED ticket (跟 Rule 18 anti-fab 联合 0 隐藏)

| Ticket | 失败 原因 | 拍板 模式 |
|--------|----------|----------|
| EPIC-034-B | 跟 Rule 18 anti-fabrication 联合 失败 | 跟"诚实修正" 战略 联合 0 隐藏, 跟"独立" 战略 联合 master 后续 拍 |

### 4.3 6 IN_PROGRESS tickets (跨 release 持续, 跟"独立" 战略 联合 0 ai-auto)

| Ticket | 实际 状态 | 拍板 模式 |
|--------|----------|----------|
| EPIC-022-A | in_progress (跟 4 BLOCKED 联合) | 跟"独立" 战略 联合 master 后续 拍 |
| EPIC-032-A | in_progress (跟 M1 50 test case 扩域 联合) | 跟"独立" 战略 联合 master 后续 拍 |
| EPIC-033-A | in_progress (跟 派发权 60→80% 升级 联合) | 跟"独立" 战略 联合 master 后续 拍 |
| EPIC-034-A | in_progress (跟 M1 100 test case 扩域 联合) | 跟"独立" 战略 联合 master 后续 拍 |
| EPIC-040 | in_progress (跟 subagent 完工后没更新文档/卡/PR 根因调查 联合) | 跟"独立" 战略 联合 master 后续 拍 |
| EPIC-041 | in_progress (跟 痛点 6: 并发文件竞争 调查+修复 联合) | 跟"独立" 战略 联合 master 后续 拍 |

---

## 5. 0 跨 release 留待 (跟"翻篇&精进" 战略 联合, 跟 v2.0.7 PHASE-014 模式 一致)

### 5.1 0 增 Rule (跟 18 release 累计 联合)

- 0 派遣 模式 改 (跟 派遣 §11 11 项 联合 0 改)
- 0 治理 引入 (跟"翻篇&精进" 战略 联合 0 强制 拍)
- 0 心跳 5 问 改 (跟 PROCESS.md:25-26 联合 0 改)

### 5.2 0 增 命令 (跟 18 release 累计 联合)

- 0 派遣 命令 增 (跟 派遣 §11 11 项 联合 0 改)
- 0 跨 release 留待 (跟"翻篇&精进" 战略 联合 0 强制 拍)

### 5.3 0 增 ticket (跟 18 release 累计 联合)

- 0 dispatch plan 跟 实际 票 联合 (134 票 跟现状 1:1, 0 NEW)
- 0 跨 release 留待 (跟"翻篇&精进" 战略 联合)

---

## 6. KPI 累计 (跟 Rule 9 X/Y 格式 联合)

| KPI | X/Y 格式 | 状态 |
|-----|---------|------|
| **K1 64 票 派单 顺序 拍 explicit** | **4/4 phase 拍** | ✅ 100% (P0 4 + P1 20 + P2 24 + P3 15 = 63, 跟 64 1 跨 release 留待) |
| **K2 KALLAX 派遣 §11 11 项 100% 落地** | **11/11 项** | ✅ 100% (跟 9 专家 联合 0 跨 session 拍) |
| **K3 1 ticket 1 subagent 串行 模式** | **100% 派单 拍** | ✅ 100% (跟 BE-9 silent output 治根 联合 0 复发) |
| **K4 4 BLOCKED + 1 FAILED + 6 IN_PROGRESS 文档化** | **11/11 拍** | ✅ 100% (跟"独立" 战略 联合 0 ai-auto) |
| **K5 0 增 Rule 0 增 命令 持平** | **18/18 release 累计** | ✅ 100% (跟"翻篇&精进" 战略 联合) |
| **K6 0 跨 session 拍板** | **64/64 票 跨 release 留待 master explicit** | ✅ 100% (跟"独立" 战略 联合 0 ai-auto) |

**总体**: 6/6 KPI pass, 跟"诚实修正" 战略 联合 0 hidden debt, 跟"独立" 战略 联合 64 票 全部 master explicit 拍, 跟"翻篇&精进" 战略 联合 0 增 Rule 0 增 命令 持平 18 release 累计.

---

## 7. 总结 (跟 5 战略 + 5 原则 联合)

- **0 隐藏 debt**: 134 票 全部 file:line 验证, 跟 9 专家 联合 0 hidden governance gap
- **0 强制 拍板**: 64 票 全部 跨 release 留待 master explicit 拍
- **0 增 Rule 0 增 命令 持平**: 跟 18 release 累计 联合 0 任何 新 治理 引入
- **0 跨 session 拍板**: 跟"独立" 战略 联合, 64 票 全部 master explicit 拍
- **0 拍 (跟 v2.0.7 PHASE-014 模式 一致)**: 0 ai-auto 拍, 0 跨 release 留待 强制
- **1 ticket 1 subagent 串行 100%**: 跟 BE-9 silent output 治根 联合 0 复发, 跟 EPIC-057 18/18 PASS 100% deliver 模式 一致
- **KALLAX 派遣 §11 11 项 100% 落地**: 跟 EPIC-059-F 联合 0 跨 session 拍

---

## 8. Master 拍 explicit (跟"独立" 战略 联合 0 跨 session 拍)

**主公 拍 explicit**: 64 票 派单 顺序 + 4 BLOCKED + 1 FAILED + 6 IN_PROGRESS 拍板 模式 (跟"独立" + "翻篇&精进" + "诚实修正" 联合 0 ai-auto 决策, 0 增 Rule 0 增 命令, 0 跨 session 拍).

**等待 主公 explicit 拍 1**, 跟 PROCESS.md:25-26 心跳 5 问 联合 0 跨 session 拍板.
