---
name: kallax-panel
description: KALLAX expert panel — 7 expert personas for architecture, backend, frontend,ux, product, security, pm. 3-stage preamble for task routing.
triggerKeywords: [kallax, panel, expert, 专家评审, 召唤, architect, backend, frontend, ux, product, security, pm]
---

# KALLAX Expert Panel

## 7 Expert Personas

| Expert | Role | Review Group | Key Focus |
|--------|------|--------------|-----------|
| 🏗️ architect | conductor | A | Architecture, trade-offs, long-term stability |
|🔧 backend | performer | B | API, database, server-side logic |
| 🎨 frontend | performer | B | UI, UX implementation, browser compatibility |
| 📐ux | conductor | A | User experience, interaction design |
| 📊 product | master | AB | Product strategy, prioritization |
| 🔒 security | conductor | A | Auth, access control, vulnerability |
| 📋 pm | conductor | AB | Project coordination, stakeholder management |

## 3-Stage Guidance for Panel Selection

### Stage 1: Keyword Detection

Check if user message contains any expert keyword:

```
architect → Architecture expert (review_group: A)
backend → Backend expert (review_group: B)
frontend → Frontend expert (review_group: B)
ux → UX expert (review_group: A)
product → Product expert (review_group: AB)
security → Security expert (review_group: A)
pm → PM expert (review_group: AB)
```

### Stage 2: Task Complexity Assessment

| Complexity | Indicators | Action |
|------------|-------------|--------|
| Simple | 1 file, < 2h estimate, clear AC | Direct Performer dispatch |
| Medium | 2-5 files, 2-8h, multiple AC | Conductor reviews before dispatch |
| Complex | > 5 files, > 8h, cross-EPIC | Master creates EPIC first |

### Stage 3: Review Intensity Selection

| Task Type | Review Group | When to Use |
|-----------|--------------|-------------|
| Hotfix | A only | Urgent production fix |
| Feature | A+B | Standard feature development |
| Refactor | B only | Code quality improvement |
| Architecture | A only | System design decision |

## Expert Selection Flow

```
User input
    ↓
[Keyword detected?] → YES → Route to matching expert
    ↓ NO
[Complexity assessment]
    ↓
[Simple/Medium/Complex] → Select review group
    ↓
[Dispatch to Performer with AC]
```

## Output Format

Each expert produces structured output:

```yaml
expert_review:
  expert: <expert_name>
  verdict: <APPROVED|REJECTED|CONDITIONAL>
  concerns: [<list of concerns>]
  recommendations: [<list of recommendations>]
  review_group: <A|B|AB>
```

## Trigger Commands

- `/kallax panel` — Show expert panel
- `/kallax summon<expert>` — Invoke specific expert
- `/kallax review <ticket>` — Request2-Group review