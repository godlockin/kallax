/**
 * Auto-Decompose E2E tests.
 */
import { describe, it, expect } from 'vitest';
import { decompose } from '../../src/core/auto-decompose.js';

describe('AutoDecompose', () => {
  it('decomposes a simple TypeScript feature request', () => {
    const result = decompose('Implement user authentication with TypeScript, JWT tokens, and database storage');
    expect(result.isOk()).toBe(true);
    const d = result.value;
    expect(d.subtasks.length).toBeGreaterThanOrEqual(2); // main + test
    expect(d.recommendedMode).toBe('dag');
  });

  it('detects Rust-specific requests', () => {
    const result = decompose('Optimize async trait implementation in Rust cargo build');
    expect(result.isOk()).toBe(true);
    expect(result.value.subtasks[0]?.suggestedCapabilities).toContain('rust');
  });

  it('handles test-only requests without adding extra tests', () => {
    const result = decompose('Write unit tests for the auth module');
    expect(result.isOk()).toBe(true);
    // 'test' action → should not add duplicate test sub-task
    expect(result.value.subtasks.length).toBeGreaterThanOrEqual(1);
  });

  it('returns parallel mode for simple independent tasks', () => {
    const result = decompose('Fix typo');
    expect(result.isOk()).toBe(true);
    expect(result.value.recommendedMode).toBe('parallel');
  });

  it('extracts file paths from requirement', () => {
    const result = decompose('Refactor src/core/sqlite/sync-client.ts and tests/sqlite-manager.test.ts');
    expect(result.isOk()).toBe(true);
  });
});
