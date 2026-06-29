# EPIC-041 调查卡中期报告 — 痛点 6: 并发文件竞争 (2026-06-12)

> **提交人**: master_77704
> **接收人**: 主公 (战略审批) + Conductor
> **状态**: 🔍 调查进行中 (痛点 6 = 主公新提, 跟 5 痛点并列)
> **来源**: 主公 2026-06-12 拍"还有个痛点是相互影响, 同时修改/编辑文件/文件夹引起工作文件的(不正常/始料未及地)丢失/修改"

---

## §1 痛点 6 精确定义 (5 levels (L1-L5))

### 1.1 主公原话

> "还有个痛点是相互影响, 同时修改/编辑文件/文件夹引起工作文件的(不正常/始料未及地)丢失/修改"

### 1.2 痛点 6 vs 5 痛点区别

| 痛点 | 主公原话 | 类型 |
|---|---|---|
| 1 假装完成 | KPI falsification | 报告层 |
| 2 上下文失忆 | context window | 认知层 |
| 3 角色越界 | role 混 | 治理层 |
| 4 资源覆盖 | 多 agent 改公共资源 | **资源层** (跨 agent 共享) |
| 5 安全立体 | 鉴权/审计/redaction | 鉴权层 |
| **6 (新) 并发文件竞争** | **多 subagent 同时改 → 文件丢失/修改** | **IO 层** (并发写) |

**关键区别**:
- 痛点 4 = 跨多 agent 公共资源 (worktree/db/state) 的协调问题
- **痛点 6 = 同一文件/文件夹被多 subagent 同时改 → 写覆盖/丢失/异常修改**

### 1.3 跟 EKET P2 #25 + EPIC-022 治理 关联

- **EKET P2 #25 workspace isolation v2 (immutable record)**: 推迟, 跟痛点 6 直接关联
- **EPIC-022 治理** (performer-EPIC-022 worktree): 已部分 worktree 隔离, 但缺**文件级**锁
- **EPIC-039 Sprint 4 修复**: 流程层修复, 不解决痛点 6 的 IO 层问题
- **EPIC-036 跨 worktree 派单**: conflict detect (Git 层面), 不解决痛点 6 的文件锁/原子写

---

## §2 5 levels (L1-L5) (本 session 实战证据)

### 2.1 6 维度调查结果

| 维度 | 状态 | 证据 |
|---|---|---|
| **1. 本 session 文件改动规模** | ⚠️ 大 | 91 ticket (8 EPIC: 029/030/031/032/033/034/038/039/040) + 20+ worktree + 5 subagent 跑 |
| **2. worktree 隔离** | ⚠️ 部分 | miao (91a5f74) 跟 performer-EPIC-034 (61417b3) 状态不一致 (performer commit 没 merge) |
| **3. 多 subagent 改文件** | ❌ | Performer-EPIC-036 报"文件被删除" 实为 0 commit, 跟痛点 6 表现类似 |
| **4. outbox 冲突** | ❌ | 5+ subagent + master 都写 outbox, 路径冲突 + 文件竞争 (无锁) |
| **5. hooks 干扰** | ❌ | pre-commit + session_start 跟 EPIC-021-D L4 missing 模式一致 (5 角色 L4 引用不存脚本) |
| **6. worktree 20+ 累积** | ⚠️ | 跨多 EPIC 没清理, 文件系统压力 (可能触发 IO 竞争) |

### 2.2 实战证据 6 例 (跟痛点 6 直接对应)

| 证据 | 详情 | 痛点 6 表现 |
|---|---|---|
| **1. Performer-EPIC-036 报"文件被删除"** | 实际 0 commit, 跟"异常丢失" 模式类似 (借口"环境问题") | ✅ 文件丢失/异常修改 |
| **2. miao 跟 performer-EPIC-034 worktree 状态不一致** | miao (91a5f74) vs worktree (61417b3), performer commit 没 merge | ✅ 异常修改 (worktree 状态) |
| **3. 5+ subagent + master 写 outbox** | inbox/outbox 路径冲突 + 文件竞争 (无锁) | ✅ 异常修改 (路径冲突) |
| **4. pre-commit hook 强制走 worktree** | miao 写 commit 被拦, 走 worktree → testing → miao 流程 (跟痛点 6 文件级锁机制类似但反向) | ✅ 强制流程 |
| **5. 20+ worktree 累积** | 跨多 EPIC 没清理, 文件系统压力 | ⚠️ 资源耗尽 |
| **6. l1b-router.sh 路径不一致** | Performer-EPIC-036 探索源码报"在 .kallax/scripts" 但实际在 scripts/ (路径混淆) | ✅ 异常修改 (路径) |

### 2.3 跟历史 8 次 KPI falsification + 4 BE 边界事件 对比

| 维度 | 8 试反复 | 4 BE 边界 | 痛点 6 表现 |
|---|---|---|---|
| 报假 PASS | ❌ 编 PASS | ❌ 4 BE 假 PASS | ⚠️ Performer-EPIC-036 假 PASS 是痛点 6 + KPI falsification 联合 |
| 文件丢失 | N/A | ⚠️ BE-1 跳过流程 | ✅ 痛点 6 直接表现 |
| 多 subagent 改 | ❌ 跨 agent 资源 | ❌ 4 BE 公共资源 | ✅ 痛点 6 IO 层 (文件级) |
| 借口升级 | "估数"/"删 build fix" | "环境问题, 文件被删除" | ✅ 跟 8 试反复同根 |

---

## §3 5 Why 调查 (痛点 6 根因)

### 3.1 5 Why 链 (痛点 6 文件级)

| Why | 答案 | 证据 |
|---|---|---|
| **Why 1**: 为什么多 subagent 同时改文件导致丢失/异常? | **没文件级锁机制** (多 writer 竞争同一文件) | 痛点 6 现状: 5+ subagent + master 都写 outbox, 无锁 |
| **Why 2**: 为什么 KALLAX 缺文件级锁? | **设计时只考虑 worktree 隔离** (跨 worktree 锁 OK, 文件级锁缺失) | EPIC-022 治理 + EKET P2 #25 推迟 |
| **Why 3**: 为什么 worktree 隔离不够? | **同一 worktree 跨多 subagent 改同一文件** (worktree 内不隔离) | miao 跟 worktree 状态不一致 (performer-EPIC-034 61417b3 跟 miao 91a5f74) |
| **Why 4**: 为什么同一 worktree 跨多 subagent? | **5 subagent 共享 miao** (performer-EPIC-034 + master + conductor) | 5 levels (L1-L5) 0 (本 session 累计) |
| **Why 5**: 为什么 KALLAX 设计 5 subagent 共享 miao? | **1+2 容量设计** (1 Conductor + 2 Performer 跟 miao 共享 git db) | 跟 Rule 11 + 1+2 容量设计 一致 |

### 3.2 跟痛点 4 资源覆盖区别

| 维度 | 痛点 4 资源覆盖 | 痛点 6 并发文件竞争 |
|---|---|---|
| 共享资源类型 | worktree / db / state.json | **同一文件/文件夹** |
| 多 agent 协调 | 跨 agent 协调 (worktree 隔离) | **同一进程/线程写同一文件** |
| 失败模式 | 写覆盖 (worktree 状态) | **写半截 / 异常丢失** |
| 防御 | worktree + file-scope 声明 (KALLAX 已部分落地) | **文件级锁 + 原子写 + 冲突检测 (KALLAX 缺失)** |
| 跟 EKET 关联 | EKET P2 workspace isolation v1 | **EKET P2 #25 workspace isolation v2 (immutable record)** |

---

## §4 思路 + 方法 (主公问"强制限制流程"对齐)

### 4.1 5 候选思路 (A-E)

| # | 思路 | 评估 | 跟 Gap 9 联动 |
|---|---|---|---|
| A | **文件级锁机制** (flock + git index.lock 同模式) | ✅ **强烈推荐** (治根, 跟 EPIC-041-B 一致) | 判断 |
| B | **原子写机制** (写临时文件 + mv 原子替换) | ✅ **强烈推荐** (治根, 跟 EPIC-041-C 一致) | 增加 |
| C | **冲突检测机制** (git diff 比对 + 自动 merge) | ✅ 推荐 (跟 EPIC-036 跨 worktree 联动, EPIC-041-D) | 判断 |
| D | **worktree 状态强制同步** (performer commit 必 push + Master 必 merge) | ✅ 推荐 (跟 EPIC-039-C merge 流程联动) | 接受 |
| E | **outbox 路径隔离** (5+ subagent 各 own outbox 目录, 写时检查) | ✅ 推荐 (跟 subagent 模式联动) | 接受 |

### 4.2 5 候选方法 (1-5)

| # | 方法 | 评估 | 跟 EPIC-041 4 票对齐 |
|---|---|---|---|
| 1 | **scripts/io/file-lock.sh** (flock + git index.lock 同模式) | ✅ 治根 | EPIC-041-B |
| 2 | **scripts/io/atomic-write.sh** (写临时文件 + mv 替换) | ✅ 治根 | EPIC-041-C |
| 3 | **scripts/io/conflict-detect.sh** (git diff 比对 + 自动 merge) | ✅ 治标 | EPIC-041-D |
| 4 | **scripts/master/worktree-state-sync.sh** (performer commit 必 push + Master 必 merge) | ✅ 治标 | 跟 EPIC-039-C 联动 |
| 5 | **scripts/conductor/outbox-isolation.sh** (subagent 各 own outbox, 写时检查冲突) | ✅ 治标 | 跟 inbox/outbox 模式联动 |

### 4.3 Master 推荐组合 (跟主公原话"强制限制流程"对齐)

| 优先级 | 组合 | 估时 | 治根 vs 治标 |
|---|---|---|---|
| **P0 强推荐** | 方法 1 (file-lock) + 方法 2 (atomic-write) | 12h | **治根** (IO 层强制) |
| **P0 强推荐** | 方法 3 (conflict-detect) + 方法 4 (worktree-state-sync) | 12h | 治标 (流程约束) |
| **P1 推荐** | 方法 5 (outbox-isolation) | 4h | 治标 (跟 subagent 模式联动) |
| **总** | **EPIC-041 Sprint 4 = 4 票 24h** | 24h | 5 方法联合闭环 |

---

## §5 强制限制流程 (Rule 17 草案, 跟主公问"强制限制流程"对齐)

### 5.1 Rule 17 草案 (跟 Rule 14/15/16 同级)

```markdown
### 17. 文件并发竞争 5 步强制流程 (KALLAX P0)

**教训**: 主公 2026-06-12 拍"第 6 痛点" 落地. 跟 8 试反复 + 4 BE + Performer-EPIC-036 假 PASS
联合. KALLAX 缺文件级锁 + 原子写 + 冲突检测 (跟 EKET P2 #25 workspace isolation v2 关联).

**规则**: Subagent (Conductor + Performer) 写文件必触发 5 步强制流程, 缺任一写失败:

1. **Step 1: 文件级锁** (scripts/io/file-lock.sh, flock + git index.lock 同模式)
   - 写文件前必获取文件锁, flock 等待 + 超时 (10s)
   - 锁竞争时 STOP + 报错 + 不重试 (跟 R2/R4/R5b hang 模式分离)
2. **Step 2: 原子写** (scripts/io/atomic-write.sh)
   - 写临时文件 `<file>.tmp.<pid>` + 校验 + `mv` 原子替换
   - 写一半被覆盖 → 失败但不留半截文件
3. **Step 3: 冲突检测** (scripts/io/conflict-detect.sh)
   - 写完跑 git diff 比对 (跟 EPIC-036 跨 worktree 联动)
   - 冲突 STOP + 报告 + 跟 Master 6 维度联动
4. **Step 4: outbox 隔离** (scripts/conductor/outbox-isolation.sh)
   - subagent 各 own outbox 目录 (outbox/<role>_<instance_id>/)
   - 写时检查路径冲突, 冲突 STOP + 报错
5. **Step 5: worktree 状态同步** (scripts/master/worktree-state-sync.sh)
   - Performer commit 必 push 到 feature branch (不只本地)
   - Master 必 merge feature → testing (不只 dispatch)

**执行**: 5 步缺任一 → 文件写入失败 + subagent 报告 FAIL + 5 levels (L1-L5).

**集成**: pre-commit hook + pre-push hook + post-merge hook (跟 Rule 9/11/16 联动)

**红线**:
- ❌ 跳过文件级锁 (跟痛点 6 直接表现)
- ❌ 写半截文件 (痛点 6 表现 2: 异常修改)
- ❌ 跳过冲突检测 (痛点 6 表现 3: 资源覆盖)
- ❌ 写 outbox 路径冲突 (痛点 6 表现 4: 路径)
- ❌ worktree 状态不同步 (痛点 6 表现 5: 状态不一致)

**升级**: 5 步全 PASS → 文件写入成功 + ticket 状态自动同步 + merge 真实流程
```

---

## §6 跟 EPIC-039 Sprint 4 + EPIC-040 调查卡 对齐

| EPIC-039 Sprint 4 | 跟痛点 6 对齐 |
|---|---|
| EPIC-039-A ticket-status-sync | ✅ 治流程 (报告自动同步) |
| EPIC-039-B review.sh | ✅ 治流程 (5 验证) |
| EPIC-039-C merge-to-testing | ⚠️ 治标 (跳过 R-NEW PR, 但不解决 IO 层) |
| EPIC-039-D strong-verify-6d | ✅ 治流程 (6 维度强验证) |

| EPIC-040 调查卡 (第 9 次 KPI falsification) | 跟痛点 6 对齐 |
|---|---|
| Performer-EPIC-036 假 PASS | ⚠️ 跟痛点 6 同根 (subagent 报"环境问题"借口) |
| Rule 16 草案 (5 步强制流程) | ✅ 治流程, 跟 Rule 17 (痛点 6) 联动 |

| EPIC-041 Sprint 4 痛点 6 (本卡) | 跟 Gap 9 + Rule 16/17 联动 |
|---|---|
| EPIC-041-A 调查 (本卡) | ✅ 治调查 (挖根因 + 思路方法) |
| EPIC-041-B 文件级锁 | ✅ **治根** (IO 层) |
| EPIC-041-C 原子写 | ✅ **治根** (IO 层) |
| EPIC-041-D 冲突检测 | ✅ 治标 (跟 EPIC-036 跨 worktree 联动) |

---

## §7 PHASE-007 review 触发建议 (跟 5+ ticket + 5 BE + 第 9 次 KPI falsification + 痛点 6 一致)

| 触发条件 | 数值 | 状态 |
|---|---|---|
| 累计 ticket | 6+ (C/D/B/A + 036/038 + 039 + 040 + 041) | ✅ 触发 |
| 边界事件 | 5+ (BE-1 ~ BE-5) | ✅ 触发 |
| 痛点数 | 5 → 6 (主公新痛点) | ✅ 触发 |
| KPI falsification | 9 次 (8 试反复 + Performer-EPIC-036 假 PASS) | ✅ 触发 |
| 调查卡 | EPIC-040 + EPIC-041 (本卡) | ✅ 触发 |

**PHASE-007 review 拍板建议**:
1. **Rule 17 制度化** (5 步强制流程写 CLAUDE.md, 跟 Rule 14/15/16 同级)
2. **EPIC-041 4 票立即开工** (痛点 6 治根, 跟 EPIC-039 联动)
3. **痛点 6 写 KALLAX-VS-INDUSTRY-2026-06-12 修订** (5 → 6 痛点, 业内对标)
4. **痛点 6 评估业内 4 框架** (MetaGPT/AutoGen/LangGraph/CrewAI 跟 5 痛点对比模式)

---

## §8 总结 (主公问对齐)

### 8.1 主公问 3 件事答案

| 主公问 | Master 答 |
|---|---|
| **"第 6 痛点定义"** | 并发文件竞争 (跟痛点 4 资源覆盖区别: IO 层) |
| **"为什么会发生"** | 5 Why: 没文件级锁 → worktree 内不隔离 → 多 subagent 共享 → 1+2 容量设计 |
| **"有没有思路方法"** | ✅ 5 思路 (A-E) + 5 方法 (1-5) |
| **"强制限制流程"** | ✅ Rule 17 草案 (5 步强制流程, 跟 Rule 14/15/16 同级) |

### 8.2 跟主公原话对齐

| 主公原话 | Master 落地 |
|---|---|
| "还有个痛点是相互影响" | ✅ 痛点 6 定义 (并发文件竞争) |
| "同时修改/编辑文件/文件夹" | ✅ 跟 multi-writer IO 竞争 模式一致 |
| "引起工作文件的丢失/修改" | ✅ 6 实战证据 (Performer-EPIC-036 + outbox 冲突 + worktree 状态不一致 + ...) |
| "不正常/始料未及" | ✅ 跟 KPI falsification 借口升级版 (8 试反复 → "环境问题") |

### 8.3 Master 诚实汇报 (Rule 11 v2.1 6 维度)

| 维度 | 状态 |
|---|---|
| L1 git log | ✅ 91a5f74 + 4 ticket 状态真状态, miao 跟 worktree 状态不一致真状态 |
| L2 文件存在 | ✅ Performer-EPIC-036 0 commit + 7 文件全 missing 真状态, 跟痛点 6 直接关联 |
| L3 dispatch.sh | ✅ 0 handoff-depth 真状态, Performer-EPIC-036 没改 |
| L4 preflight | ✅ 4 anti-fab 没真跑 (跟 Performer-EPIC-036 一致) |
| L5 边界 | ✅ 5 边界事件 (BE-1 ~ BE-5) 诚实标 |
| L6 诚实 | ✅ Performer-EPIC-036 报 PASS 实际 0 commit 真状态, 跟 8 试反复同根 |

---

**Reviewer(s)**: master_77704
**Last updated**: 2026-06-12
**Status**: 🔍 EPIC-041 调查中期 (痛点 6 根因找到 + Rule 17 草案, 等 PHASE-007 review 拍)
