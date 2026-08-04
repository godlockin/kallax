# Self-Repair Skill — Reference Documentation

> **EPIC-164** (v3.32.9, 2026-08-05)
> 借鉴 loopx `skills/loopx-self-repair/SKILL.md` (5 步 repair loop + dream-up 机制)
> 跟 EPIC-161 retrospective-routine 互补: 阶段性回顾 vs 运行时自修复

---

## Overview

Self-Repair Skill 自动检测和处理 KALLAX 框架内的重复错误、行为异常和系统性失败.

**触发条件**:
- 同一错误出现 ≥ 3 次
- 错误 bypass 标准修复路径
- Agent 行为异常
- `check-self-heal.sh` 检测到反模式

---

## 5-Step Repair Loop (详细)

### Step 0 — Trigger Detection

检查是否满足 self-repair 条件:
- 重复错误 ≥ 3 次
- 错误模式异常
- Smoke/benchmark 与 reality 失配

### Step 1 — Pause Delivery

**立即暂停** 当前 quota/adapter work:
```
[Self-Repair] Delivery paused. Activating 5-step repair loop.
```

**Allowed**: 读取 structured surfaces, 构建 evidence packet, 跟 Master 沟通
**Forbidden**: 继续交付, 提交未验证修复, 降 gate/workaround

### Step 2 — Build Evidence Packet

收集结构化证据 (不读 raw private logs):

```json
{
  "symptom": "string",
  "frequency": 3,
  "first_occurrence": "2026-08-05T00:00:00Z",
  "last_occurrence": "2026-08-05T12:00:00Z",
  "affected_layer": "agent|state|docs|benchmark|harness",
  "context": {
    "ticket_id": "EPIC-XXX",
    "task_type": "quota|adapter|smoke|retrospective",
    "error_pattern": "string",
    "attempted_fixes": []
  },
  "primary_blocker": "string",
  "contradictory_signals": []
}
```

### Step 3 — Classify Failure (5 类型)

| Type | 描述 | Evidence |
|------|------|----------|
| `agent mistake` | Agent 自身判断/执行错误 | 同一 agent 多次失败, 错误不一致 |
| `state projection bug` | Active-state projection 错误 | state.json 与实际状态不一致 |
| `active-state authoring gap` | State 写入逻辑缺失 | 应该有写入但实际没有 |
| `benchmark harness mismatch` | Smoke/benchmark 与 reality 失配 | Smoke PASS 但 prod FAIL |
| `docs process hygiene` | 文档/流程不一致 | 文档说了但实际没做 |

### Step 4 — Assign Responsible Layer

治根原则: 优先修复最低层

```
Priority: skill > docs > projection > smoke > process > agent
```

### Step 5 — Repair at Lowest Durable Layer

| Layer | Action |
|-------|--------|
| skill | 更新 `.claude/skills/kallax-self-repair/SKILL.md` |
| docs | 更新 `docs/reference/` 或 `confluence/decisions/` |
| projection | 修复 `.kallax/state/state.json` 逻辑 |
| smoke | 更新 `tests/integration/kallax-self-repair.test.sh` |
| process | 更新 `CLAUDE.md` 或 `.claude/rules/` |
| agent | 修正 prompt/指令 |

---

## Dream-Up Mechanism

重复错误 (≥ 3 次) 视为 **product/process gap**, 触发 dream-up:

### Dream-Up 流程

```
重复错误 → Dream-Up Mode 激活
↓
判断: 是否有 ticket?
├─ 有 ticket → 标注 "cascading failure from TICKET-XXX"
├─ 无 ticket → 创建 defect ticket
↓
选择更新目标 (优先级递减):
├─ skill → docs → projection → smoke → process
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

## Evidence Discipline

| ✅ DO | ❌ DON'T |
|-------|---------|
| 从 structured surfaces 提取 | 读 raw private logs |
| 明确标注 unverified hypothesis | solve contradictory by guessing |
| 记录 primary blocker | hide primary blocker |

---

## Vision/Replan Writeback

修复完成后写回 `state.json`:

```json
{
  "self_repair": {
    "completed_at": "2026-08-05T12:00:00Z",
    "classification": "agent mistake",
    "responsible_layer": "skill",
    "dream_up_targets": ["skill", "docs"],
    "next_action": "resume"
  }
}
```

---

## Installation

```bash
# Install self-repair skill for Claude Code
bash scripts/install.sh --install-skill kallax-self-repair

# Or via Omnibus (EPIC-160 pattern)
bash scripts/install.sh --target=claude --install-skill kallax-self-repair
```

---

## Testing

```bash
# Run self-repair smoke tests
bash tests/integration/kallax-self-repair.test.sh

# Expected: 10/10 PASS
```

---

## Reference

| 文档 | 路径 |
|------|------|
| Self-Repair Skill | `.claude/skills/kallax-self-repair/SKILL.md` |
| Repair Agent | `.claude/skills/kallax-self-repair/agents/repair-agent.md` |
| Branch Flow | `.claude/rules/branch-flow.md` |
| State JSON | `.claude/rules/state-json.md` |
| Test Pattern | `.claude/rules/testing.md` |
| Retrospective Routine | `scripts/retrospective-routine.sh` (EPIC-161) |
| LoopX Gap Analysis | `confluence/decisions/loopx-vs-kallax-skill-gap-2026-08-05.md` |
