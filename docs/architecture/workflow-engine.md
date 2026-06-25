# Workflow Engine

> Design document for the KALLAX workflow lifecycle management system.

---

## Overview

The Workflow Engine provides template-based workflow execution for common development patterns. It defines reusable step sequences and manages their lifecycle — from template selection through step-by-step execution to completion.

---

## Architecture

```
  ┌──────────────────────────────────────────────────────┐
  │                   Workflow Engine                     │
  │                                                       │
  │  ┌──────────────┐    ┌───────────────────────────┐   │
  │  │  Templates    │    │  WorkflowExecutor          │   │
  │  │              │    │                            │   │
  │  │  List of     │    │  - start(template, args)   │   │
  │  │  named       │    │  - step(workflowId)        │   │
  │  │  workflows   │    │  - status(workflowId)      │   │
  │  └──────────────┘    │  - cancel(workflowId)      │   │
  │                       └───────────────────────────┘   │
  └──────────────────────────────────────────────────────┘
            │                       │
            ▼                       ▼
  ┌──────────────────┐   ┌──────────────────────────┐
  │   Ticket Engine   │   │   External Systems       │
  │   (state machine) │   │   (git, CI, deploy)      │
  └──────────────────┘   └──────────────────────────┘
```

---

## Templates

Workflow templates define a named sequence of steps. Each step has a type and configuration.

### Built-in Templates

| Template | Steps | Description |
|----------|-------|-------------|
| `feature-development` | 5 | Create branch, implement, test, review, merge |
| `bugfix` | 4 | Reproduce, fix, verify, deploy |
| `documentation` | 3 | Draft, review, publish |

### Template Definition

```typescript
interface WorkflowTemplate {
  name: string;
  description: string;
  steps: WorkflowStep[];
}

interface WorkflowStep {
  name: string;
  type: 'create_branch' | 'run_command' | 'create_pr' | 'wait_for_check' | 'merge';
  config: Record<string, unknown>;
}
```

---

## Lifecycle

### States

```
DRAFT → ACTIVE → STEP_IN_PROGRESS → ---→ COMPLETED
                                  ↘
                                  FAILED (with partial step state)
                                  ↙
                                CANCELLED
```

### Execution Flow

1. **Select**: User picks a template by name.
2. **Start**: Engine creates a workflow instance in `ACTIVE` state.
3. **Execute**: Steps run sequentially via `step()` calls. Each step is atomic.
4. **Complete**: All steps done → status becomes `COMPLETED`.
5. **Fail**: Any step error → status becomes `FAILED` with error context.

### Saga Integration

Each workflow step is a Saga step with a compensate function:

```typescript
const featureSteps: SagaStep<WorkflowState>[] = [
  {
    name: 'create-branch',
    execute: async (s) => { /* git branch create */ },
    compensate: async (s) => { /* git branch delete */ },
  },
  {
    name: 'implement',
    execute: async (s) => { /* code changes */ },
    compensate: async (s) => { /* git revert */ },
  },
];
```

---

## Concurrency Model

- Workflows are sequential within a single instance (no parallel steps).
- Multiple workflow instances can run concurrently for different tickets.
- Isolation is enforced per-ticket: each workflow operates on its own worktree.

---

## CLI Integration

```bash
# List templates
kallax workflow list

# Start a workflow
kallax workflow start feature-development TICKET-ABC

# Advance to next step
kallax workflow step <workflow-id>

# Check status
kallax workflow status <workflow-id>

# Cancel
kallax workflow cancel <workflow-id>
```

---

## Related

- `node/src/commands/workflow-cmd.ts` — CLI command registration
- `node/src/core/workflow/` — Workflow engine implementation
- `docs/architecture/FRAMEWORK.md` — Overall architecture
- `docs/guides/quick-start.md` — Getting started
