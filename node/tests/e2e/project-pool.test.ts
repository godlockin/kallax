/**
 * KALLAX E2E: Cross-Project Pool
 * Tests: project registration, performer allocation/release,
 * resource isolation, priority-based rebalancing, global stats.
 */

import { describe, it, expect, beforeEach } from 'vitest';
import { createProjectPool, type ProjectPool, type ProjectConfig } from '../../src/core/project-pool.js';

// ============================================================================
// Helpers
// ============================================================================

const PROJECT_A: ProjectConfig = {
  projectId: 'project-alpha',
  maxPerformers: 3,
  priority: 100,
  allowedCapabilities: ['typescript', 'node'],
};

const PROJECT_B: ProjectConfig = {
  projectId: 'project-beta',
  maxPerformers: 2,
  priority: 50,
  allowedCapabilities: ['python'],
};

const PROJECT_C: ProjectConfig = {
  projectId: 'project-gamma',
  maxPerformers: 4,
  priority: 200,
  allowedCapabilities: [],
};

// ============================================================================
// Tests
// ============================================================================

describe('ProjectPool', () => {
  let pool: ProjectPool;

  beforeEach(() => {
    pool = createProjectPool();
  });

  // ── Registration ──────────────────────────────────────────────────────────

  describe('registration', () => {
    it('registers a project and returns initial allocation', () => {
      const result = pool.registerProject(PROJECT_A);
      expect(result.isOk()).toBe(true);

      const alloc = pool.getProjectAllocation('project-alpha');
      expect(alloc.projectId).toBe('project-alpha');
      expect(alloc.allocatedPerformers).toEqual([]);
      expect(alloc.availableSlots).toBe(3);
      expect(alloc.queueDepth).toBe(0);
    });

    it('rejects registration with maxPerformers < 1', () => {
      const result = pool.registerProject({ ...PROJECT_A, maxPerformers: 0 });
      expect(result.isErr()).toBe(true);
      expect(result._unsafeUnwrapErr().code).toBe('INVALID_ARGUMENT');
    });

    it('updates existing project config on re-registration', () => {
      pool.registerProject(PROJECT_A);
      const updated: ProjectConfig = { ...PROJECT_A, maxPerformers: 5, priority: 200 };
      const result = pool.registerProject(updated);
      expect(result.isOk()).toBe(true);

      const alloc = pool.getProjectAllocation('project-alpha');
      expect(alloc.availableSlots).toBe(5);
    });

    it('deallocates excess performers when maxPerformers is reduced', () => {
      pool.registerProject({ ...PROJECT_A, maxPerformers: 5 });

      // Allocate 4 performers
      for (let i = 0; i < 4; i++) {
        pool.allocatePerformer(`perf-${i}`, 'project-alpha');
      }

      // Reduce max to 2 — should deallocate 2 excess
      pool.registerProject({ ...PROJECT_A, maxPerformers: 2 });

      const alloc = pool.getProjectAllocation('project-alpha');
      expect(alloc.allocatedPerformers.length).toBe(2);
    });
  });

  // ── Allocation & Release ──────────────────────────────────────────────────

  describe('allocation and release', () => {
    it('allocates a performer to a registered project', () => {
      pool.registerProject(PROJECT_A);
      const result = pool.allocatePerformer('perf-1', 'project-alpha');
      expect(result.isOk()).toBe(true);

      const alloc = pool.getProjectAllocation('project-alpha');
      expect(alloc.allocatedPerformers).toContain('perf-1');
      expect(alloc.availableSlots).toBe(2);
    });

    it('rejects allocation to unregistered project', () => {
      const result = pool.allocatePerformer('perf-1', 'nonexistent');
      expect(result.isErr()).toBe(true);
      expect(result._unsafeUnwrapErr().code).toBe('INVALID_ARGUMENT');
    });

    it('rejects allocation when project is at capacity', () => {
      pool.registerProject(PROJECT_B); // maxPerformers = 2
      pool.allocatePerformer('perf-1', 'project-beta');
      pool.allocatePerformer('perf-2', 'project-beta');

      const result = pool.allocatePerformer('perf-3', 'project-beta');
      expect(result.isErr()).toBe(true);
      expect(result._unsafeUnwrapErr().message).toContain('at capacity');
    });

    it('rejects allocation when performer is already allocated elsewhere', () => {
      pool.registerProject(PROJECT_A);
      pool.registerProject(PROJECT_B);
      pool.allocatePerformer('perf-1', 'project-alpha');

      const result = pool.allocatePerformer('perf-1', 'project-beta');
      expect(result.isErr()).toBe(true);
      expect(result._unsafeUnwrapErr().code).toBe('INSTANCE_ALREADY_EXISTS');
    });

    it('allows re-allocation to same project (idempotent)', () => {
      pool.registerProject(PROJECT_A);
      pool.allocatePerformer('perf-1', 'project-alpha');
      const result = pool.allocatePerformer('perf-1', 'project-alpha');
      expect(result.isOk()).toBe(true);
    });

    it('releases a performer from a project', () => {
      pool.registerProject(PROJECT_A);
      pool.allocatePerformer('perf-1', 'project-alpha');
      const result = pool.releasePerformer('perf-1');
      expect(result.isOk()).toBe(true);

      const alloc = pool.getProjectAllocation('project-alpha');
      expect(alloc.allocatedPerformers).not.toContain('perf-1');
      expect(alloc.availableSlots).toBe(3);
    });

    it('returns error when releasing unknown performer', () => {
      const result = pool.releasePerformer('nonexistent');
      expect(result.isErr()).toBe(true);
      expect(result._unsafeUnwrapErr().code).toBe('INSTANCE_NOT_FOUND');
    });
  });

  // ── Resource Isolation ────────────────────────────────────────────────────

  describe('resource isolation', () => {
    it('keeps performer allocations separate between projects', () => {
      pool.registerProject(PROJECT_A);
      pool.registerProject(PROJECT_B);

      pool.allocatePerformer('perf-ts-1', 'project-alpha');
      pool.allocatePerformer('perf-py-1', 'project-beta');

      const allocA = pool.getProjectAllocation('project-alpha');
      const allocB = pool.getProjectAllocation('project-beta');

      expect(allocA.allocatedPerformers).toEqual(['perf-ts-1']);
      expect(allocB.allocatedPerformers).toEqual(['perf-py-1']);
      expect(allocA.availableSlots).toBe(2);
      expect(allocB.availableSlots).toBe(1);
    });

    it('project capacity does not affect other projects', () => {
      pool.registerProject({ ...PROJECT_A, maxPerformers: 1 });
      pool.registerProject({ ...PROJECT_B, maxPerformers: 10 });

      pool.allocatePerformer('perf-a', 'project-alpha');

      // Project A is full
      const result = pool.allocatePerformer('perf-a2', 'project-alpha');
      expect(result.isErr()).toBe(true);

      // Project B still has capacity
      for (let i = 0; i < 5; i++) {
        const r = pool.allocatePerformer(`perf-b-${i}`, 'project-beta');
        expect(r.isOk()).toBe(true);
      }

      const allocB = pool.getProjectAllocation('project-beta');
      expect(allocB.allocatedPerformers.length).toBe(5);
      expect(allocB.availableSlots).toBe(5);
    });
  });

  // ── Global Stats ──────────────────────────────────────────────────────────

  describe('global stats', () => {
    it('returns zero stats for empty pool', () => {
      const stats = pool.getGlobalStats();
      expect(stats.totalProjects).toBe(0);
      expect(stats.totalPerformers).toBe(0);
      expect(stats.utilizationPercent).toBe(0);
    });

    it('returns correct stats with multiple projects', () => {
      pool.registerProject({ ...PROJECT_A, maxPerformers: 3 }); // cap 3
      pool.registerProject({ ...PROJECT_B, maxPerformers: 2 }); // cap 2
      pool.registerProject({ ...PROJECT_C, maxPerformers: 4 }); // cap 4

      pool.allocatePerformer('p1', 'project-alpha');
      pool.allocatePerformer('p2', 'project-alpha');
      pool.allocatePerformer('p3', 'project-beta');

      const stats = pool.getGlobalStats();
      expect(stats.totalProjects).toBe(3);
      expect(stats.totalPerformers).toBe(3);
      expect(stats.utilizationPercent).toBe(33); // 3/9 = 33%
    });
  });

  // ── Rebalance ─────────────────────────────────────────────────────────────

  describe('rebalance', () => {
    it('does nothing with fewer than 2 projects', () => {
      pool.registerProject(PROJECT_A);
      pool.rebalance(); // should not throw
      const alloc = pool.getProjectAllocation('project-alpha');
      expect(alloc.allocatedPerformers).toEqual([]);
    });

    it('does not move performers if high-priority project has no available slots', () => {
      // Both projects at capacity — no room to steal into
      pool.registerProject({ projectId: 'high', maxPerformers: 2, priority: 200, allowedCapabilities: [] });
      pool.registerProject({ projectId: 'low', maxPerformers: 3, priority: 100, allowedCapabilities: [] });

      pool.allocatePerformer('h1', 'high');
      pool.allocatePerformer('h2', 'high');
      for (let i = 0; i < 3; i++) {
        pool.allocatePerformer(`l${i}`, 'low');
      }

      // high has 0 available slots → rebalance skipped
      pool.rebalance();

      const allocHigh = pool.getProjectAllocation('high');
      const allocLow = pool.getProjectAllocation('low');
      expect(allocLow.allocatedPerformers.length).toBe(3);
      expect(allocHigh.allocatedPerformers.length).toBe(2);
    });

    it('moves performers from low-priority to high-priority project', () => {
      // High priority project has capacity, low priority project has performers → rebalance moves them
      pool.registerProject({ projectId: 'high', maxPerformers: 5, priority: 200, allowedCapabilities: [] });
      pool.registerProject({ projectId: 'low', maxPerformers: 3, priority: 100, allowedCapabilities: [] });

      for (let i = 0; i < 3; i++) {
        pool.allocatePerformer(`perf-lp-${i}`, 'low');
      }
      pool.allocatePerformer('perf-hp-1', 'high');

      // Before: high has 1/5 (4 free), low has 3/3 (full)
      const beforeHigh = pool.getProjectAllocation('high');
      const beforeLow = pool.getProjectAllocation('low');
      expect(beforeHigh.allocatedPerformers.length).toBe(1);
      expect(beforeLow.allocatedPerformers.length).toBe(3);

      // Rebalance should move 3 from low to high (limited by high's 4 free slots)
      pool.rebalance();

      const afterHigh = pool.getProjectAllocation('high');
      const afterLow = pool.getProjectAllocation('low');

      expect(afterLow.allocatedPerformers.length).toBe(0);
      expect(afterHigh.allocatedPerformers.length).toBe(4);
    });

    it('steals only up to the available capacity of the high-priority project', () => {
      pool.registerProject({ projectId: 'high', maxPerformers: 3, priority: 200, allowedCapabilities: [] });
      pool.registerProject({ projectId: 'low', maxPerformers: 5, priority: 100, allowedCapabilities: [] });

      pool.allocatePerformer('h1', 'high');
      for (let i = 0; i < 5; i++) {
        pool.allocatePerformer(`l${i}`, 'low');
      }

      // high has 2 free slots, low has 5 → steal at most 2
      pool.rebalance();

      const afterHigh = pool.getProjectAllocation('high');
      const afterLow = pool.getProjectAllocation('low');

      expect(afterHigh.allocatedPerformers.length).toBe(3); // now full
      expect(afterLow.allocatedPerformers.length).toBe(3); // lost 2
    });
  });

  // ── End-to-End Flow ───────────────────────────────────────────────────────

  describe('end-to-end flow', () => {
    it('register 2 projects, allocate performers, verify isolation, rebalance', () => {
      // Step 1: Register 2 projects with different priorities
      pool.registerProject({ projectId: 'web-app', maxPerformers: 5, priority: 200, allowedCapabilities: ['typescript', 'react'] });
      pool.registerProject({ projectId: 'data-pipeline', maxPerformers: 3, priority: 50, allowedCapabilities: ['python', 'sql'] });

      // Step 2: Allocate performers to each project
      pool.allocatePerformer('perf-ts-1', 'web-app');
      pool.allocatePerformer('perf-ts-2', 'web-app');
      pool.allocatePerformer('perf-py-1', 'data-pipeline');

      // Step 3: Verify isolation
      const webAlloc = pool.getProjectAllocation('web-app');
      const dataAlloc = pool.getProjectAllocation('data-pipeline');

      expect(webAlloc.allocatedPerformers).toContain('perf-ts-1');
      expect(webAlloc.allocatedPerformers).toContain('perf-ts-2');
      expect(webAlloc.allocatedPerformers).not.toContain('perf-py-1');
      expect(webAlloc.availableSlots).toBe(3);

      expect(dataAlloc.allocatedPerformers).toContain('perf-py-1');
      expect(dataAlloc.allocatedPerformers).not.toContain('perf-ts-1');
      expect(dataAlloc.availableSlots).toBe(2);

      // Step 4: Fill data-pipeline to capacity
      pool.allocatePerformer('perf-py-2', 'data-pipeline');
      pool.allocatePerformer('perf-py-3', 'data-pipeline');

      // Step 5: Rebalance — web-app (high priority) has capacity, steal from data-pipeline (low priority)
      pool.rebalance();

      const afterWeb = pool.getProjectAllocation('web-app');
      const afterData = pool.getProjectAllocation('data-pipeline');

      // data-pipeline should have lost performers to web-app
      expect(afterData.allocatedPerformers.length).toBeLessThan(3);
      // web-app should have gained them
      expect(afterWeb.allocatedPerformers.length).toBeGreaterThan(2);
    });

    it('performer flows across projects with capacity changes', () => {
      pool.registerProject({ projectId: 'frontend', maxPerformers: 2, priority: 100, allowedCapabilities: ['react'] });
      pool.registerProject({ projectId: 'backend', maxPerformers: 2, priority: 100, allowedCapabilities: ['node'] });

      // Allocate performers
      pool.allocatePerformer('perf-a', 'frontend');

      // Release and re-allocate
      pool.releasePerformer('perf-a');
      const alloc1 = pool.getProjectAllocation('frontend');
      expect(alloc1.allocatedPerformers).not.toContain('perf-a');

      pool.allocatePerformer('perf-a', 'backend');
      const alloc2 = pool.getProjectAllocation('backend');
      expect(alloc2.allocatedPerformers).toContain('perf-a');

      // Global stats reflect the move
      const stats = pool.getGlobalStats();
      expect(stats.totalPerformers).toBe(1);
      expect(stats.totalProjects).toBe(2);
    });
  });
});
