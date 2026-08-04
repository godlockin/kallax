---
name: kallax-self-repair
description: Use when agent encounters repeated failures, behavior anomalies, or systemic errors that bypass standard fixes. Activates the 5-step repair loop: pause delivery → build evidence packet → classify failure → assign responsible layer → repair at lowest durable layer. Triggers on: "self-repair", "重复错误", "行为异常", "systematic failure", "fix the fix", "repair loop", "dream-up", "product gap", "process gap".
triggerKeywords: [self-repair, 重复错误, 行为异常, systematic failure, fix the fix, repair loop, dream-up, product gap, process gap, repair skill, self-heal 反模式, recurring bug, persistent error, failure classification]
enabled_policy: true
skill_scope: self-repair
version: "1.0.0"
---

> **EPIC-164**: 借鉴 loopx `skills/loopx-self-repair/SKILL.md` (5 步 repair loop + dream-up 机制)
> **跟 EPIC-161 retrospective-routine 互补**: retrospective = 阶段性回顾, self-repair = 运行时自修复

# KALLAX Self-Repair Skill

## 5-Step Repair Loop (跟 loopx-self-repair 1:1)

### Step 0 — Trigger Detection

当以下任一条件满足时，激活 self-repair loop:
- 同一错误出现 ≥ 3 次 (重复错误)
- 错误 bypass 标准修复路径
- Agent 行为异常 (输出质量下降、流程偏离)
- `check-self-heal.sh` 检测到 self-heal 反模式

**不激活条件**:
- 单次新错误 (标准 debug 流程即可)
- 简单 typo 或 input error
- 已知 bug 已在 backlog (有 ticket)

---

### Step 1 — Pause Delivery

**立即暂停当前任务/交付**, 不继续 quota / adapter work.

```
输出: "[Self-Repair] Delivery paused. Activating 5-step repair loop."
```

**为什么**: 防止错误扩大化, 避免 cascading failure.

**Allowed actions during pause**:
- 读取 structured surfaces (status / diagnose / quota)
- 构建 evidence packet
- 跟 Master 沟通 (如需要)

**Forbidden during pause**:
- 继续 quota/adapter work
- 提交未验证的修复
- 降 gate / workaround / commit private logs

---

### Step 2 — Build Evidence Packet

收集 structured evidence (不读 raw private logs):

```
Evidence Packet {
  symptom: string           // 症状描述
  frequency: int            // 出现次数
  first_occurrence: string  // ISO timestamp
  last_occurrence: string   // ISO timestamp
  affected_layer: string     // 推测层 (agent/state/docs/benchmark/harness)
  context: {
    ticket_id: string?
    task_type: string       // quota/adapter/smoke/retrospective
    error_pattern: string   // 错误模式分类
    attempted_fixes: []     // 已尝试的修复 (0 = 未尝试)
  }
  primary_blocker: string    // 主要阻塞因素 (如果有)
  contradictory_signals: [] // 矛盾信号 (如果有)
}
```

**Evidence Discipline**:
- ❌ 不读 raw private logs (输出噪音太大)
- ❌ 不 solve contradictory by guessing (矛盾信号需要明文记录)
- ❌ 不 hide primary blocker (主要阻塞因素必须公开)
- ✅ 从 structured surfaces 提取 (status / diagnose / quota should-run)
- ✅ 如需 raw log, 只读最后 50 行, 明确标注为 "unverified hypothesis"

---

### Step 3 — Classify Failure

分类失败类型 (5 类, 跟 loopx 1:1):

| Type | 描述 | 判断条件 |
|------|------|----------|
| **agent mistake** | Agent 自身判断/执行错误 | 同一 agent 多次失败, 错误不一致 |
| **state projection bug** | Active-state projection 错误 | `state.json` 与实际状态不一致 |
| **active-state authoring gap** | State 写入逻辑缺失 | 应该有写入但实际没有 |
| **benchmark harness mismatch** | Smoke/benchmark 与 reality 失配 | Smoke PASS 但 prod FAIL |
| **docs process hygiene** | 文档/流程不一致 | 文档说了但实际没做 |

**输出**:
```
Classification: <type>
Confidence: high/medium/low
Evidence: <key evidence for this classification>
```

---

### Step 4 — Assign Responsible Layer

治根 (lowest durable layer):

```
Responsible Layer = min(durability, [
  "skill"           // skill 更新
  "docs"            // 文档修正
  "projection"       // state projection 修复
  "smoke"           // smoke test 更新
  "process"         // 流程/Rule 变更
  "agent"           // agent 行为修正
])
```

**原则**:
- 优先更新最低层 (skill > docs > projection > smoke > process > agent)
- 禁止通过降低 gate / workaround / commit private logs 来"解决"

---

### Step 5 — Repair at Lowest Durable Layer

根据 Step 4 分配的层, 执行修复:

#### 5a. Skill Update (最低层, 最优先)

更新 `.claude/skills/kallax-self-repair/SKILL.md` 或其他 skill:
- 添加新的 trigger keywords
- 修正 repair loop 步骤
- 补充 evidence discipline

#### 5b. Docs Update

更新 `docs/reference/` 或 `confluence/decisions/`:
- 添加 decision record
- 记录 known issue
- 补充 troubleshooting guide

#### 5c. Projection Fix

修复 state projection bug:
- 修正 `.kallax/state/state.json` 写入逻辑
- 修正 `scripts/` 中的 state 操作

#### 5d. Smoke Update

更新 smoke test:
- 添加 regression case
- 更新 `tests/integration/kallax-self-repair.test.sh`

#### 5e. Process/Rule Update

更新 `CLAUDE.md` 或 `.claude/rules/`:
- 添加新的 Rule (如需要)
- 修正 process gap

#### 5f. Agent Behavior Correction

修正 agent 自身:
- 调整 prompt/指令
- 添加新 agent 到 `agents/`

---

## Dream-Up Mechanism (重复错误处理)

当同一错误出现 ≥ 3 次, 视为 **product/process gap**, 触发 dream-up:

### Dream-Up 流程

```
重复错误 → Dream-Up Mode 激活
↓
判断: 是否有 ticket?
├─ 有 ticket → 标注 "cascading failure from TICKET-XXX"
├─ 无 ticket → 创建 defect ticket
↓
选择更新目标:
├─ skill (最优先) — 更新 SKILL.md
├─ docs — 更新 reference docs
├─ projection — 修复 state projection
├─ smoke — 更新 smoke test
└─ process — 更新 CLAUDE.md / rules
↓
验证修复: 重新跑 should-run
↓
输出: Dream-Up Report
```

### Dream-Up 禁止事项

- ❌ 降 gate (降低测试标准)
- ❌ workaround (临时绕过而非治根)
- ❌ commit private logs (不公开日志)
- ❌ 静默忽略 (必须 writeback)

---

## Vision/Replan Writeback

修复完成后, 必须写回 active state:

```bash
# 更新 state.json
# 1. 标记 repair completed
# 2. 记录 dream-up target
# 3. 更新 next_action

# 格式:
state.json {
  "self_repair": {
    "completed_at": "<ISO timestamp>",
    "classification": "<type>",
    "responsible_layer": "<layer>",
    "dream_up_targets": ["<skill|docs|projection|smoke|process>"],
    "next_action": "<resume|escalate>"
  }
}
```

**如需要 escalation**:
```
输出: "[Self-Repair] Escalating to Master. Classification: <type>, Layer: <layer>."
```

---

## Reference Routes

| 文档 | 路径 |
|------|------|
| Self-Repair 详细用法 | `docs/reference/kallax-self-repair-2026-08-05.md` |
| Branch Flow Governance | `.claude/rules/branch-flow.md` |
| State JSON 路径约定 | `.claude/rules/state-json.md` |
| Test Pattern | `.claude/rules/testing.md` |
| Retrospective Routine | `scripts/retrospective-routine.sh` (EPIC-161) |
| Decision Records | `confluence/decisions/` |
| LoopX vs KALLAX Gap | `confluence/decisions/loopx-vs-kallax-skill-gap-2026-08-05.md` |

---

## Exit Codes

```
0 = Repair completed, delivery can resume
1 = Classification failed (contradictory evidence)
2 = No repair possible at lowest layer (escalate to Master)
```

---

## Related Skills

| Skill | 关系 |
|-------|------|
| `kallax` | 主 skill, self-repair 是子 skill |
| `kallax-experts/*` | 如需 expert review, 触发 `/kallax-expert process-engineering` |
| `retrospective-routine` | EPIC-161, 互补: 阶段性 vs 运行时 |

---

## Test Coverage

```bash
# Run self-repair smoke tests
bash tests/integration/kallax-self-repair.test.sh

# Expected: ≥6 test cases PASS
```
