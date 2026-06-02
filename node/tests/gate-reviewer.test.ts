/**
 * Gate Reviewer Unit Tests
 */

import { describe, it, expect } from 'vitest';
import { createGateReviewer } from '../src/core/gate-reviewer.js';

describe('GateReviewer', () => {
  it('creates gate reviewer instance', () => {
    const reviewer = createGateReviewer();
    expect(reviewer).toBeDefined();
    expect(typeof reviewer.review).toBe('function');
    expect(typeof reviewer.reviewPr).toBe('function');
  });

  it('runs preflight checks (Gate 1)', async () => {
    const reviewer = createGateReviewer();
    const result = await reviewer.review({ maxLevel: 1, cwd: process.cwd() });
    expect(result.isOk()).toBe(true);
    if (result.isOk()) {
      expect(result.value.maxLevel).toBe(1);
      expect(result.value.checks.length).toBeGreaterThan(0);
      // Should have git-repository check
      expect(result.value.checks.some((c) => c.name === 'git-repository')).toBe(true);
      expect(result.value.checks.some((c) => c.name === 'uncommitted-changes')).toBe(true);
    }
  });

  it('runs architecture checks (Gate 2)', async () => {
    const reviewer = createGateReviewer();
    const result = await reviewer.review({ maxLevel: 2, cwd: process.cwd() });
    expect(result.isOk()).toBe(true);
    if (result.isOk()) {
      expect(result.value.checks.some((c) => c.level === 2)).toBe(true);
    }
  });

  it('runs security checks (Gate 3)', async () => {
    const reviewer = createGateReviewer();
    const result = await reviewer.review({ maxLevel: 3, cwd: process.cwd() });
    expect(result.isOk()).toBe(true);
    if (result.isOk()) {
      expect(result.value.checks.some((c) => c.level === 3)).toBe(true);
    }
  });

  it('skips tests when skipTests is true', async () => {
    const reviewer = createGateReviewer();
    const result = await reviewer.review({ maxLevel: 4, skipTests: true, cwd: process.cwd() });
    expect(result.isOk()).toBe(true);
  });

  it('builds correct summary', async () => {
    const reviewer = createGateReviewer();
    const result = await reviewer.review({ maxLevel: 1, cwd: process.cwd() });
    expect(result.isOk()).toBe(true);
    if (result.isOk()) {
      expect(result.value.summary.total).toBeGreaterThan(0);
      expect(typeof result.value.summary.passed).toBe('number');
      expect(typeof result.value.summary.failed).toBe('number');
      expect(result.value.passed).toBe(result.value.summary.failed === 0);
    }
  });

  it('marks failed when checks fail', async () => {
    const reviewer = createGateReviewer();
    // Run in a non-git directory to force failure
    const result = await reviewer.review({ maxLevel: 1, cwd: '/tmp' });
    expect(result.isOk()).toBe(true);
    if (result.isOk()) {
      // In /tmp without git, preflight should fail
      const gitCheck = result.value.checks.find((c) => c.name === 'git-repository');
      if (gitCheck && gitCheck.status === 'failed') {
        expect(result.value.passed).toBe(false);
      }
    }
  });
});
