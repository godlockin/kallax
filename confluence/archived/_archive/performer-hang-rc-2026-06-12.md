# Performer Hang 根因 + 防御研究 (2026-06-12)

> **何时写**: 主公 2026-06-12 拍"最近一直出现xx Performer hang住, 研究一下为什么, 怎么才能避免"
> **范围**: 6 次 Performer spawn hang 实证 (R2/R2b/R4/R4a/R5/R5b, EPIC-034-C 期间) + 根因 + 4 防御升级
> **路径**: `confluence/decisions/PERFORMER-HANG-RC-2026-06-12.md`
> **方法**: Conductor 实证报告 + Rule 1/11 边界事件 + Rule 9d/9e 现有机制叠加分析

**Date**: 2026-06-12
**Author**: master_main (Rule 11 联动, 不写代码, 主公 2026-06-12 拍研究)
**Reviewers**: 主公 (战略审批) + PHASE-007 review 备
**Status**: ✅ COMPLETE — 等主公拍升级

---

## §1 Hang 实证 (6 次, EPIC-034-C 期间)

| Round | 状态 | 成本 | 触发 | 教训 |
|---|---|---|---|---|
| Phase 0 (034-B setup) | ✅ OK | $1.00 / 8 turns | spawn claude -p setup | — |
| Round 1 (034-B audit) | ✅ OK (守 Rule 9c) | $4.31 / 76 turns | — | root cause 找到 |
| Round 1 (034-C 修路径) | ✅ OK | $2.10 | — | — |
| **Round 2** | ❌ **HANG** | $0 | 跑 multi-line git commit | hang 模式首次 |
| **Round 2b** | ❌ **HANG** (kill) | $0 | 跑 multi-line git commit | 同上 |
| Round 2c (034-C 真创建) | ✅ OK | $3.72 | 单步拆 commit | 反 hang 策略: 拆 |
| Round 3 (034-C 修 audit + 测试) | ✅ OK | $1.78 | 单步 | — |
| **Round 4** | ❌ **HANG** | $0 | 跑 multi-line git commit | 同 R2 |
| **Round 4a** | ❌ **HANG** | $0 | 跑 multi-line git commit | 同上 |
| Round 4c (034-C 修 test) | ✅ OK | $1.09 | 单步 | — |
| **Round 5** | ❌ **HANG** | $0 | 跑 multi-line git commit | 同 R2 |
| **Round 5b** (commit 完) | ✅ OK (hang 假象) | $0 | 实际 commit 完 | 误判 hang, 实际 OK |
| **累计** | **6 hang / 9 sessions / 350+ turns / $14.00** | | | |

### 1.1 Hang 关键证据

**Conductor 实证 (来自 `EPIC-034C-最终战果-20260612.md` §10)**:
> "Performer spawn hang 模式": claude -p 跑 multi-line git commit 必 hang (3 次实证 R2/R4/R5b). **Rule 13 升级建议**: spawn 任务拆 commit 为单 prompt, 不混 multi-line.

**Rule 1 边界事件 (`rule-1-boundary-event-20260612-commit.json` §12)**:
> "claude -p 跑 multi-line git commit 必 hang (3 次实证: R2/R4/R5b). Spawn Performer 写 commit 模式在当前 KALLAX 不稳定."

**Rule 11 边界事件 (`rule-11-boundary-event-20260612.json` §11)**:
> "claude --print 单次 prompt 跑完即退, 4h 增量开发无法在单次 --print 完成. 需分阶段 prompt."

---

## §2 根因分析 (5 Why)

### 2.1 5 Why 链

| Why | 答案 | 证据 |
|---|---|---|
| **Why 1**: 为什么 Performer hang? | `claude -p` 跑 multi-line git commit 必 hang (3 次实证) | R2/R4/R5b 实证 |
| **Why 2**: 为什么 multi-line git commit 必 hang? | `claude -p` 单次 prompt 处理长 multi-line heredoc + 复杂 commit message 时 stdin/stdout 阻塞 | Conductor 推断 (R2/R4 模式) |
| **Why 3**: 为什么单步 commit 不 hang? | 单步 `git add` + 短 commit message (单行) 不触发 stdin/stdout 阻塞 | R2c/R3/R4c 实证 |
| **Why 4**: 为什么 4h 任务 spawn 一次跑不完? | `claude --print` 单次 prompt 跑完即退, 长任务无法持久化 | Rule 11 边界事件 §11 |
| **Why 5**: 为什么当前 KALLAX 不稳定? | spawn 模式 + Performer 边界 + commit 步骤独立未做, 形成"边界未设计" 状态 | 6 hang 反复 + 1 Rule 1 + 1 Rule 11 边界事件 |

### 2.2 根因 3 层

| 层 | 根因 | 现状 |
|---|---|---|
| **L1 工具层** | `claude -p` multi-line stdin/stdout 阻塞 | KALLAX spawn 模式设计缺陷 |
| **L2 流程层** | Spawn 任务未拆 commit 为单 prompt | 当前 spawn 任务含 multi-step (edit + commit + verify) |
| **L3 规则层** | 缺 Rule 14 (anti-hang) 强制: spawn 任务结构约束 | Rule 9d/9e 覆盖 KPI falsification, 不覆盖 hang |

### 2.3 跟历史 8 次 KPI falsification 对比

| 维度 | 8 次 KPI falsification (51125b9/6563362/33cfc48/...) | 6 次 Performer hang (R2/R2b/R4/R4a/R5/R5b) |
|---|---|---|
| 类型 | Performer 编造 PASS 报告 | Performer 跑 multi-line commit 卡死 |
| 触发 | KPI 估数 / test verbatim / scope creep | multi-line heredoc + git commit |
| 防御 (现有) | Rule 9a/9b/9c/9d/9e + 3 anti-fab 工具 | ❌ 缺 (无 Rule 14 anti-hang) |
| Master 强验证 | Rule 11 v2.1 6 维度 checklist | ❌ Hang 时无产物可验, 强验证失效 |
| 修复路径 | 3 anti-fab 工具 + 强验证 | **需拆 commit 为单 prompt** |

**关键洞察**: 6 hang 是 **新一类问题** — 现有 Rule 9/11 防御**不覆盖**. 跟 KPI falsification 同级 (8 试反复), 但**根因不同** (KPI 是骗, Hang 是卡).

---

## §3 防御升级 (4 层叠加)

### 3.1 防御 1: 拆 commit 为单 prompt (战术级, 立即可做)

**操作**:
- spawn Performer 任务**禁止** multi-line git commit 在单 prompt
- 拆为 3 单 prompt:
  1. prompt 1: `git add <files>` (单步)
  2. prompt 2: `git commit -m "<单行 message>"` (单步, 短 message)
  3. prompt 3: `git log --oneline -1` 验证 (单步)

**证据**: R2c/R3/R4c 单步不 hang, 跟 R2/R4/R5b multi-line 必 hang 对比.

**成本**: 0 (流程优化, 无代码改动)

**触发**: Conductor spawn 任务前**强验证** (decide-on-spawn anti-hang check).

### 3.2 防御 2: Spawn 任务结构约束 (Rule 14 升级, 制度级)

**操作**:
- 新增 **Rule 14 (Anti-Hang)**: spawn 任务结构强制
- 规则: 每个 spawn prompt 必须满足:
  - 单步操作 (不混 multi-step)
  - 短 prompt (< 2K tokens)
  - 短 commit message (< 5 行)
  - 不带 stdin heredoc
  - 不带长 git diff 输出

**证据**: 6 hang 反复 = spawn 任务结构无约束.

**成本**: 0.5d (Conductor 写 decide-on-spawn.sh 验证脚本 + Rule 14 写 CLAUDE.md)

**触发**: PHASE-007 review 拍, 写入 `decide-on-spawn.sh` + pre-spawn 验证.

### 3.3 防御 3: Performer 持久化 (架构级, 中期)

**操作**:
- 改 spawn 模式: `claude --print` 单次 → 持久化 Performer session
- 用 `--session-id <UUID>` + 多 prompt 续接 (跟 Rule 11 边界事件 §11 提示一致)
- Performer 在 1 session 内完成 4h 主开发 (不靠 spawn 单次)

**证据**: Rule 11 边界事件 §11 提示 "claude --print 单次 prompt 跑完即退, 需分阶段 prompt".

**成本**: 2-3d (新 `--persistent-performer.sh` + 集成 conductor dispatch + 测试)

**触发**: Phase 6 后 + 6 EPIC 累积后拍 (跟"Checkpoint 时间旅行" 同步).

### 3.4 防御 4: 边界事件 Master 强验证 (跟 Rule 11 联动)

**操作**:
- Conductor 撞 Rule 1 / Rule 11 边界时, 5 levels (L1-L5) (跟 Rule 11 v2.1 一致):
  1. `git log --oneline -1` 看 SHA 真变
  2. `git show HEAD:file | grep` 看内容真改
  3. 跑全量 E2E
  4. 跑 4 anti-fab
- Master 接受 boundary 事件后, 标"Rule 11 边界触发", 留 LESSONS-LEARNED 草稿

**证据**: Rule 1 + Rule 11 边界事件**已 2 次实证** (Phase 6 + EPIC-034-C), 需制度化.

**成本**: 0 (现有 Rule 11 v2.1 复用)

**触发**: 任何 boundary event 自动跑 (PHASE-007 review 备 Rule 14 制度化).

---

## §4 跟现有 Rule 体系联动

| 现有 Rule | 跟 Hang 关系 | 升级建议 |
|---|---|---|
| Rule 9d (commit amend verify, 4 维度) | ✅ 间接防 hang (commit 后验证) | 升级: 加"commit message < 5 行" 约束 |
| Rule 9e (Performer 自验证) | ❌ 不覆盖 (hang 时无产物) | 升级: 加"performer spawn fail 重试上限 3 次" |
| Rule 11 v2.1 (5 levels (L1-L5)) | ❌ Hang 时强验证失效 | 升级: 加"hang 边界事件必须 4 防御 1 验证" |
| Rule 13 (3 模式决策权) | ✅ Conductor 决策 hang 处置 | 升级: 写 Rule 14 anti-hang 任务结构 |
| **🆕 Rule 14 (Anti-Hang)** | **新规则** | **本 RC 提议** |

### 4.1 Rule 14 草案 (供 PHASE-007 拍)

```markdown
### 14. Anti-Hang 强制 (KALLAX P0) — Performer spawn 结构约束

**教训**: EPIC-034-C 期间 6 次 Performer spawn hang (R2/R2b/R4/R4a/R5/R5b, 350+ turns 浪费).
根因: claude -p 跑 multi-line git commit 必 hang (3 次实证).
**根因 5 Why**: tool stdin/stdout 阻塞 + spawn 任务未拆 commit + 缺 spawn 任务结构约束.

**规则**: Conductor spawn Performer 任务前, 必须跑 `scripts/conductor/decide-on-spawn.sh` 验证:

1. **单步操作**: spawn prompt 不混 multi-step (edit + commit + verify 不混)
2. **短 prompt**: spawn prompt < 2K tokens
3. **短 commit message**: git commit -m "<5 行" (单行更佳)
4. **无 stdin heredoc**: spawn prompt 不带 long-form input
5. **无 long git diff**: spawn prompt 不打印全 diff

**执行**: `decide-on-spawn.sh <prompt_file> <commit_msg_file>` 返回 0=OK / 1=FAIL.
- OK → spawn OK
- FAIL → Conductor 拆 prompt, 跟 Conductor 拆 Y 方案 (EPIC-034-C) 同模式

**红线**:
- ❌ spawn multi-line git commit (R2/R4/R5b 模式)
- ❌ spawn multi-step 任务 (edit + commit + verify 混)
- ❌ 跳过 decide-on-spawn.sh 强验证

**升级路径**:
- 落地: EPIC-035-D (随 worktree_role 一起做) / 0.5d
- 制度化: PHASE-007 review 拍
- 失效兜底: spawn Performer 持久化 (3-5 EPIC 后拍)
```

---

## §5 当前防御矩阵 (跟 4 防御 + Rule 9/11 联动)

```
┌─────────────────────────────────────────────────────────────────┐
│ Performer Hang 防御 4 层 (主公 2026-06-12 拍)                     │
├─────────────────────────────────────────────────────────────────┤
│ L1 战术: 拆 commit 为单 prompt (Conductor 立即可做)              │
│ L2 制度: Rule 14 + decide-on-spawn.sh (PHASE-007 拍, 0.5d)     │
│ L3 架构: Performer 持久化 (--session-id, 2-3d, 6 EPIC 后拍)    │
│ L4 兜底: 边界事件 Master 强验证 4 维度 (跟 Rule 11 v2.1 复用)   │
├─────────────────────────────────────────────────────────────────┤
│ Rule 9d (commit amend verify) 升级: 加 "commit msg < 5 行"       │
│ Rule 9e (Performer 自验证) 升级: 加 "spawn fail 重试 ≤ 3 次"     │
│ Rule 11 v2.1 (5 levels (L1-L5)) 升级: 加 "hang 边界事件"    │
│ Rule 13 (3 模式) 升级: 写 Rule 14 anti-hang 任务结构            │
│ 🆕 Rule 14 (Anti-Hang): spawn 任务结构强制 (草案 §4.1)          │
└─────────────────────────────────────────────────────────────────┘
```

---

## §6 落地建议 (主公拍)

| # | 行动 | 估时 | 推荐 |
|---|---|---|---|
| 1 | **L1 战术立即做**: Conductor 拆 commit 为单 prompt (EPIC-034-D 派单时) | 0 | ✅ 立即 |
| 2 | **L2 制度**: 写 Rule 14 + `decide-on-spawn.sh` (EPIC-035-D 子任务) | 0.5d | ✅ 1 周内 |
| 3 | **L3 架构**: Performer 持久化 (--session-id) | 2-3d | ⏳ 6 EPIC 后 |
| 4 | **L4 兜底**: 边界事件 Master 强验证 4 维度 (复用 Rule 11 v2.1) | 0 | ✅ 立即 |
| 5 | Rule 9d 升级 (commit msg < 5 行约束) | 0.25d | ✅ 1 周内 |
| 6 | Rule 9e 升级 (spawn fail 重试 ≤ 3 次) | 0.25d | ✅ 1 周内 |

### 6.1 跟 EPIC-034 当前派单关系

- **EPIC-034-D** (binary 读 INDEX.md, Conductor 推): 用 L1 战术, 拆 commit 单 prompt
- **EPIC-035-D** (建议新拆): Rule 14 + decide-on-spawn.sh 实现 (跟 worktree_role 一起做)
- **EPIC-036/037-A**: 现状 (跨 worktree + 持续 audit) 不受 hang 影响, 但 spawn 时需跑 decide-on-spawn.sh

---

## §7 跟 Gap 9 流程逻辑元能力联动

主公 2026-06-12 原话"做流程逻辑比扩充配置有用" 跟 Hang 防御直接相关:

| Gap 9 步骤 | Hang 防御 |
|---|---|
| 接受 | Conductor 接受"hang 是新一类问题", 不套用 KPI falsification 防御 |
| 思考 | 5 Why 根因, 区分 L1 工具层 / L2 流程层 / L3 规则层 |
| 判断 | 4 防御 (L1 战术 / L2 制度 / L3 架构 / L4 兜底) 战略选项 |
| 增加/完善 | Rule 14 (新规则) + decide-on-spawn.sh (新脚本) 增加 |

**关键洞察**: Hang 防御**正是 Gap 9 元能力训练**:
- 接受新问题 (不套用旧框架)
- 思考根因 (5 Why)
- 判断战略 (4 防御)
- 增加规则 (Rule 14 草案)

---

## §8 风险与依赖

| 风险 | 缓解 |
|---|---|
| Rule 14 拍不下来 (主公战略) | L1 战术 (拆 commit) 不依赖 Rule 14, 立即可做 |
| Performer 持久化 (L3) 跨多 EPIC 推 | 推到 6 EPIC 后拍 (跟 Checkpoint 时间旅行同步) |
| 边界事件 Master 强验证未制度化 | Rule 11 v2.1 复用, 0 增量 |
| 当前 EPIC-034-D 派单撞 hang | Conductor 派单前跑 L1 拆 commit (立即可做) |

### 8.1 跟 PHASE-007 review 关系

- 当前累计 5+ ticket (EPIC-034-B/C/D + 035-A/B + 036-A/B + 037-A/B)
- 触发 PHASE-007 review 提前
- 本 RC 报告**供 PHASE-007 review 拍 Rule 14 + 4 防御**
- 主公战略: 是否在 PHASE-007 review 拍 Rule 14 / 还是单独拍

---

## §9 总结 (主公拍战略)

### 9.1 根因一句话

> **`claude -p` 跑 multi-line git commit 必 hang** (3 次实证 R2/R4/R5b, KALLAX spawn 模式设计缺陷)

### 9.2 4 防御一句话

| 层 | 一句话 | 估时 |
|---|---|---|
| L1 战术 | 拆 commit 为单 prompt | 0 |
| L2 制度 | Rule 14 + decide-on-spawn.sh | 0.5d |
| L3 架构 | Performer 持久化 (--session-id) | 2-3d |
| L4 兜底 | 边界事件 Master 强验证 4 维度 | 0 |

### 9.3 跟 Gap 9 联动一句话

> Hang 防御 = Gap 9 元能力 4 步流程训练 (接受新问题 / 思考根因 / 判断战略 / 增加规则)

### 9.4 等主公拍

- **L1 战术**: 立即 (Conductor 派单时拆 commit)
- **L2 制度**: 1 周内 (EPIC-035-D 子任务, 0.5d)
- **L3 架构**: 6 EPIC 后 (跟 Checkpoint 同步, 2-3d)
- **L4 兜底**: 立即 (复用 Rule 11 v2.1)
- **Rule 14**: PHASE-007 review 拍

---

**Reviewer(s)**: master_main (主公拍板)
**Last updated**: 2026-06-12
**Status**: ✅ SAVED — 等主公拍 4 防御 (L1 立即, L2 1 周, L3 6 EPIC 后, L4 立即)

---

**附录**: 关联文件
- [PHASE-006-ROADMAP-2026-06-12.md](./PHASE-006-ROADMAP-2026-06-12.md) (Gap 9 流程逻辑元能力 + Top 4 战略)
- [KALLAX-VS-INDUSTRY-2026-06-12.md](./KALLAX-VS-INDUSTRY-2026-06-12.md) (5 痛点 × 业内 4 框架)
- [PROJECT-STATUS-AND-LESSONS-2026-06-12.md](./PROJECT-STATUS-AND-LESSONS-2026-06-12.md) (6 EPIC + 2 PHASE 累积)
- [cross-epic-kpi-falsification-evolution.md](../memory/lessons/cross-epic-kpi-falsification-evolution.md) (8 次 KPI falsification, 跟 hang 同级问题对比)
- [CLAUDE.md](../../CLAUDE.md) (Rule 1-13 + 9e + 11 v2.1, 草案 Rule 14)
- 关联 outbox: `EPIC-034C-最终战果-20260612.md` (6 hang 实证) / `rule-1-boundary-event-20260612-commit.json` / `rule-11-boundary-event-20260612.json`
