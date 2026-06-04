# Testing Guide

> Patterns and conventions for testing KALLAX modules.

---

## Test Runner

KALLAX uses **vitest** (Node) and **cargo test** (Rust).

```bash
# Run all tests
npm test
cargo test

# Watch mode
npm run test:watch

# Coverage
npm run test:coverage
```

---

## Node.js Test Patterns

### Unit Test Structure

```typescript
import { describe, it, expect, beforeEach } from 'vitest';

describe('TaskMatcher::matchByCapability', () => {
  let matcher: TaskMatcher;

  beforeEach(() => {
    matcher = new TaskMatcher();
  });

  it('returns empty array when no tasks available', () => {
    const result = matcher.matchByCapability('PERF-001');
    expect(result).toEqual([]);
  });

  it('scores higher for capability overlap', () => {
    matcher.registerTask({ id: 'T-1', capabilities: ['rust', 'typescript'] });
    matcher.registerTask({ id: 'T-2', capabilities: ['python'] });
    const result = matcher.matchByCapability('PERF-001', ['rust', 'typescript']);
    expect(result[0].taskId).toBe('T-1');
    expect(result[0].score).toBeGreaterThan(result[1].score);
  });
});
```

### Mocking External Dependencies

```typescript
// Use dependency injection (preferred)
describe('WorkflowEngine', () => {
  it('creates a workflow via injected git client', async () => {
    const mockGit = { createBranch: async () => 'ok' };
    const engine = new WorkflowEngine(mockGit);
    await expect(engine.start('feature', 'T-1')).resolves.not.toThrow();
  });
});

// Use vitest.fn() for simple scenarios
const mockFn = vi.fn().mockResolvedValue('fake-result');
```

### Integration Test Pattern

```typescript
describe('SQLite Integration', () => {
  let db: Database;

  beforeAll(async () => {
    db = await createTestDatabase(); // in-memory SQLite
  });

  afterAll(async () => {
    await db.close();
  });

  it('persists and retrieves tasks', async () => {
    await db.insertTask({ id: 'T-1', status: 'open' });
    const task = await db.getTask('T-1');
    expect(task.status).toBe('open');
  });
});
```

---

## Rust Test Patterns

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_topological_sort() {
        let mut dag = Dag::new();
        dag.add_edge("A", "B");
        dag.add_edge("B", "C");
        let order = dag.sort();
        assert_eq!(order, vec!["A", "B", "C"]);
    }

    #[test]
    fn test_cycle_detection() {
        let mut dag = Dag::new();
        dag.add_edge("A", "B");
        dag.add_edge("B", "A");
        assert!(dag.has_cycle());
    }
}
```

---

## Coverage Targets

| Area | Target |
|------|--------|
| Core logic (matcher, scheduler) | >90% |
| API handlers | >80% |
| CLI commands | >70% |
| UI components | >60% |

---

## CI Integration

Tests run automatically on every PR. All tests must pass before merge.

```bash
# What CI runs
npm run lint && npm run typecheck && npm test && npm run test:coverage
```

---

## Related Files

- `vitest.config.ts` — Vitest configuration
- `node/src/**/*.test.ts` — Test files co-located with source
- `rust/src/**/tests/` — Rust test modules
- `scripts/pre-commit-check.sh` — Pre-commit test runner
- `docs/guides/contributing.md` — Contribution guidelines
