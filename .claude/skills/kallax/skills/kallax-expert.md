---
name: kallax-expert
description: KALLAX expert invocation — trigger keywords, routing logic, and expert persona selection for multi-agent collaboration.
triggerKeywords: [kallax, expert, summon, invoke, architect, backend, frontend, ux, product, security, pm]
---

# KALLAX Expert Invocation

## Expert Routing Matrix

| Trigger Keyword | Expert | review_group | Primary Focus |
|-----------------|--------|--------------|---------------|
| architect, 架构, 系统设计 | architect | A | System architecture, trade-offs |
| backend, 后端, api, database | backend | B | Server-side, API design |
| frontend, 前端, ui | frontend | B | Client-side, UI implementation |
| ux, 用户体验 |ux | A | User experience, design |
| product, 产品 | product | AB | Strategy, prioritization |
| security, 安全, auth | security | A | Security, access control |
| pm, 项目管理 | pm | AB | Coordination, stakeholders |

## Invocation Flow

### Direct Invocation (Keyword Hit)

```bash
# User says something with keyword "backend"
kallax summon backend
```

1. Detect keyword in user input
2. Match to expert persona
3. Show expert panel confirmation
4. Invoke expert with context

### Preamble Flow (No Keyword)

```bash
# User says something without clear keyword
kallax preamble
```

1. **Stage 1:** No keyword detected
2. **Stage 2:** Assess task complexity
   - Ask user to classify: Simple / Medium / Complex
3. **Stage 3:** Select review intensity
   - Simple → A only (fast track)
   - Medium → A+B (standard)
   - Complex → Conductor escalation

## Expert Activation

Each expert activation is logged to `expert_invocations`:

```json
{
  "ts": "2026-06-07T12:00:00Z",
  "expert": "backend",
  "ticket": "EPIC-023-A",
  "trigger": "keyword",
  "review_group": "B"
}
```

## 2-Group Review Logic

When `review_group: AB` is selected:

1. **A-Group (Forward):** architect +ux + security
   - Focus: Architecture, design quality, security
2. **B-Group (Attack):** backend + frontend
   - Focus: Implementation correctness, edge cases

Both groups must approve for merge to `testing`.

## Expert Selection Criteria

| Criterion | Weight |
|-----------|--------|
| Keyword match | High |
| Review group alignment | High |
| Task complexity fit | Medium |
| Current workload | Low |