/**
 * KALLAX E2E: Trace Log + Session Resume
 * Tests full trace recording, chain traversal, and session checkpoint persistence.
 * Verifies traces survive restart (simulated by closing/reopening DB).
 */

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';
import Database from 'better-sqlite3';
import { initializeSchema } from '../../src/core/sqlite/schema.js';
import { createTraceLog, type TraceLog, type TraceEntry } from '../../src/core/span-tracer.js';
import { createSessionResume, type SessionResume, type SessionState } from '../../src/core/session-resume.js';

interface TestContext {
  dbPath: string;
  db: Database.Database;
  traceLog: TraceLog;
  sessionResume: SessionResume;
}

function createTestContext(): TestContext {
  const dbPath = path.join(os.tmpdir(), `kallax-e2e-trace-${Date.now()}-${Math.random().toString(36).slice(2, 8)}.db`);
  const db = new Database(dbPath);
  db.pragma('journal_mode = WAL');
  initializeSchema(db);
  const traceLog = createTraceLog(db);
  const sessionResume = createSessionResume(db);
  return { dbPath, db, traceLog, sessionResume };
}

describe('TraceLog (E2E)', () => {
  let ctx: TestContext;

  beforeEach(() => {
    ctx = createTestContext();
  });

  afterEach(() => {
    ctx.db.close();
    try { fs.unlinkSync(ctx.dbPath); } catch { /* ignore */ }
  });

  // ── Trace Recording ─────────────────────────────────────────────────────────

  it('records a trace entry and returns a valid traceId', () => {
    const traceId = ctx.traceLog.record({
      actor: 'performer-1',
      action: 'claim',
      target: 'TASK-001',
      detail: { ticketId: 'TICKET-A' },
      result: 'success',
    });

    expect(traceId).toBeTruthy();
    expect(traceId.startsWith('tr_')).toBe(true);
  });

  it('records multiple traces with unique traceIds', () => {
    const id1 = ctx.traceLog.record({
      actor: 'performer-1', action: 'claim', target: 'TASK-001',
      detail: {}, result: 'success',
    });
    const id2 = ctx.traceLog.record({
      actor: 'performer-2', action: 'claim', target: 'TASK-002',
      detail: {}, result: 'success',
    });

    expect(id1).not.toBe(id2);
  });

  it('records traces with full detail payloads', () => {
    const traceId = ctx.traceLog.record({
      actor: 'performer-1',
      action: 'complete',
      target: 'TASK-001',
      detail: {
        diffSummary: '10 files changed, 200 insertions, 50 deletions',
        testsRun: 42,
        testsPassed: 42,
        commitHash: 'abc123',
      },
      result: 'success',
    });

    const chain = ctx.traceLog.getChain(traceId);
    expect(chain).toHaveLength(1);
    expect(chain[0]?.detail).toMatchObject({
      diffSummary: expect.any(String),
      testsRun: 42,
      commitHash: 'abc123',
    });
  });

  // ── Trace Chain ─────────────────────────────────────────────────────────────

  it('returns full chain by following parentTraceId links', () => {
    // Build chain: claim → heartbeat → complete
    const claimId = ctx.traceLog.record({
      actor: 'performer-1', action: 'claim', target: 'TASK-001',
      detail: {}, result: 'success',
    });
    const heartbeatId = ctx.traceLog.record({
      actor: 'performer-1', action: 'heartbeat', target: 'TASK-001',
      detail: { progress: 50 }, result: 'pending',
      parentTraceId: claimId,
    });
    const completeId = ctx.traceLog.record({
      actor: 'performer-1', action: 'complete', target: 'TASK-001',
      detail: { progress: 100 }, result: 'success',
      parentTraceId: heartbeatId,
    });

    // getChain from any node returns full ordered chain
    const fromStart = ctx.traceLog.getChain(claimId);
    const fromEnd = ctx.traceLog.getChain(completeId);

    expect(fromStart).toHaveLength(3);
    expect(fromStart.map((e) => e.action)).toEqual(['claim', 'heartbeat', 'complete']);

    expect(fromEnd).toHaveLength(3);
    expect(fromEnd.map((e) => e.action)).toEqual(['claim', 'heartbeat', 'complete']);
  });

  it('returns single-element chain for orphan trace', () => {
    const id = ctx.traceLog.record({
      actor: 'performer-1', action: 'heartbeat', target: 'TASK-001',
      detail: {}, result: 'pending',
    });
    const chain = ctx.traceLog.getChain(id);
    expect(chain).toHaveLength(1);
    expect(chain[0]?.traceId).toBe(id);
  });

  // ── Query Traces ────────────────────────────────────────────────────────────

  it('getTaskTrace returns all traces for a task ordered by time', () => {
    ctx.traceLog.record({ actor: 'p1', action: 'claim', target: 'TASK-A', detail: {}, result: 'success' });
    ctx.traceLog.record({ actor: 'p1', action: 'heartbeat', target: 'TASK-A', detail: { progress: 30 }, result: 'pending' });
    ctx.traceLog.record({ actor: 'p2', action: 'claim', target: 'TASK-B', detail: {}, result: 'success' });
    ctx.traceLog.record({ actor: 'p1', action: 'complete', target: 'TASK-A', detail: {}, result: 'success' });

    const taskATraces = ctx.traceLog.getTaskTrace('TASK-A');
    expect(taskATraces).toHaveLength(3);
    expect(taskATraces.every((t) => t.target === 'TASK-A')).toBe(true);
    // Chronological order
    for (let i = 1; i < taskATraces.length; i++) {
      expect(taskATraces[i]!.timestamp).toBeGreaterThanOrEqual(taskATraces[i - 1]!.timestamp);
    }
  });

  it('getPerformerTrace returns all traces for a performer', () => {
    ctx.traceLog.record({ actor: 'perf-x', action: 'claim', target: 'TASK-1', detail: {}, result: 'success' });
    ctx.traceLog.record({ actor: 'perf-y', action: 'claim', target: 'TASK-2', detail: {}, result: 'success' });
    ctx.traceLog.record({ actor: 'perf-x', action: 'complete', target: 'TASK-1', detail: {}, result: 'success' });

    const perfXTraces = ctx.traceLog.getPerformerTrace('perf-x');
    expect(perfXTraces).toHaveLength(2);
    expect(perfXTraces.every((t) => t.actor === 'perf-x')).toBe(true);
  });

  it('returns empty array when no traces match query', () => {
    expect(ctx.traceLog.getTaskTrace('NONEXISTENT')).toEqual([]);
    expect(ctx.traceLog.getPerformerTrace('ghost')).toEqual([]);
    expect(ctx.traceLog.getChain('tr_nonexistent')).toEqual([]);
  });

  // ── Record all action types ─────────────────────────────────────────────────

  it('records all action types with result variants', () => {
    const actions: Array<{ action: string; result: 'success' | 'failure' | 'pending' }> = [
      { action: 'claim', result: 'success' },
      { action: 'complete', result: 'success' },
      { action: 'heartbeat', result: 'pending' },
      { action: 'review', result: 'success' },
      { action: 'claim', result: 'failure' },
      { action: 'complete', result: 'failure' },
    ];

    for (const a of actions) {
      ctx.traceLog.record({
        actor: 'tester', action: a.action, target: 'TASK-ALL',
        detail: {}, result: a.result,
      });
    }

    const all = ctx.traceLog.getTaskTrace('TASK-ALL');
    expect(all).toHaveLength(actions.length);
  });
});

describe('SessionResume (E2E)', () => {
  let ctx: TestContext;

  beforeEach(() => {
    ctx = createTestContext();
  });

  afterEach(() => {
    ctx.db.close();
    try { fs.unlinkSync(ctx.dbPath); } catch { /* ignore */ }
  });

  // ── Basic Save/Load ─────────────────────────────────────────────────────────

  it('saves and loads a checkpoint', async () => {
    const state: SessionState = {
      performerId: 'perf-save-1',
      currentTaskId: 'TASK-001',
      worktreePath: '/tmp/wt/perf-save-1',
      lastCommitHash: 'abc123def456',
      checkpointData: { step: 'development', progress: 75 },
    };

    await ctx.sessionResume.saveCheckpoint(state);

    const loaded = await ctx.sessionResume.loadCheckpoint('perf-save-1');
    expect(loaded).not.toBeNull();
    expect(loaded!.performerId).toBe('perf-save-1');
    expect(loaded!.currentTaskId).toBe('TASK-001');
    expect(loaded!.worktreePath).toBe('/tmp/wt/perf-save-1');
    expect(loaded!.lastCommitHash).toBe('abc123def456');
    expect(loaded!.checkpointData).toEqual({ step: 'development', progress: 75 });
  });

  it('returns null for unknown performer', async () => {
    const loaded = await ctx.sessionResume.loadCheckpoint('nonexistent');
    expect(loaded).toBeNull();
  });

  it('overwrites existing checkpoint on save', async () => {
    await ctx.sessionResume.saveCheckpoint({
      performerId: 'perf-overwrite',
      currentTaskId: 'TASK-001',
      checkpointData: { step: 'initial' },
    });

    await ctx.sessionResume.saveCheckpoint({
      performerId: 'perf-overwrite',
      currentTaskId: 'TASK-002',
      checkpointData: { step: 'updated', value: 42 },
    });

    const loaded = await ctx.sessionResume.loadCheckpoint('perf-overwrite');
    expect(loaded!.currentTaskId).toBe('TASK-002');
    expect(loaded!.checkpointData).toEqual({ step: 'updated', value: 42 });
  });

  it('saves checkpoint with minimal fields', async () => {
    await ctx.sessionResume.saveCheckpoint({
      performerId: 'perf-minimal',
      checkpointData: {},
    });

    const loaded = await ctx.sessionResume.loadCheckpoint('perf-minimal');
    expect(loaded!.performerId).toBe('perf-minimal');
    expect(loaded!.currentTaskId).toBeUndefined();
    expect(loaded!.worktreePath).toBeUndefined();
    expect(loaded!.lastCommitHash).toBeUndefined();
    expect(loaded!.checkpointData).toEqual({});
  });

  // ── List Sessions ───────────────────────────────────────────────────────────

  it('listSessions returns all sessions ordered by recency', async () => {
    await ctx.sessionResume.saveCheckpoint({
      performerId: 'perf-a', checkpointData: { seq: 1 },
    });
    // Small delay to ensure different updated_at
    await new Promise((r) => setTimeout(r, 10));
    await ctx.sessionResume.saveCheckpoint({
      performerId: 'perf-b', checkpointData: { seq: 2 },
    });
    await new Promise((r) => setTimeout(r, 10));
    await ctx.sessionResume.saveCheckpoint({
      performerId: 'perf-c', checkpointData: { seq: 3 },
    });

    const sessions = await ctx.sessionResume.listSessions();
    expect(sessions).toHaveLength(3);
    // Most recent first
    expect(sessions[0]!.performerId).toBe('perf-c');
    expect(sessions[2]!.performerId).toBe('perf-a');
  });

  it('listSessions returns empty array when no checkpoints exist', async () => {
    const sessions = await ctx.sessionResume.listSessions();
    expect(sessions).toEqual([]);
  });

  // ── Simulated Crash Recovery ────────────────────────────────────────────────

  it('survives simulated crash (close + reopen DB)', async () => {
    // Write checkpoint
    await ctx.sessionResume.saveCheckpoint({
      performerId: 'perf-crash',
      currentTaskId: 'TASK-042',
      worktreePath: '/tmp/wt/crash-test',
      checkpointData: { phase: 'testing', testCount: 15 },
    });

    // Record trace
    const traceId = ctx.traceLog.record({
      actor: 'perf-crash', action: 'heartbeat', target: 'TASK-042',
      detail: { progress: 60 }, result: 'pending',
    });

    // Close DB (simulate crash)
    ctx.db.close();

    // Reopen (simulate recovery)
    const db2 = new Database(ctx.dbPath);
    initializeSchema(db2);
    const traceLog2 = createTraceLog(db2);
    const sessionResume2 = createSessionResume(db2);

    try {
      // Verify checkpoint survived
      const loaded = await sessionResume2.loadCheckpoint('perf-crash');
      expect(loaded).not.toBeNull();
      expect(loaded!.currentTaskId).toBe('TASK-042');
      expect(loaded!.checkpointData).toEqual({ phase: 'testing', testCount: 15 });

      // Verify trace survived
      const chain = traceLog2.getChain(traceId);
      expect(chain).toHaveLength(1);
      expect(chain[0]!.actor).toBe('perf-crash');
      expect(chain[0]!.action).toBe('heartbeat');
    } finally {
      db2.close();
    }
  });

  // ── Integrated: Trace during session ────────────────────────────────────────

  it('records trace chain across session lifecycle', async () => {
    const performerId = 'perf-lifecycle';
    const taskId = 'TASK-LIFECYCLE';

    // Phase 1: claim task
    const claimTraceId = ctx.traceLog.record({
      actor: performerId, action: 'claim', target: taskId,
      detail: { ticketId: 'TICKET-LC' }, result: 'success',
    });
    await ctx.sessionResume.saveCheckpoint({
      performerId, currentTaskId: taskId, worktreePath: '/tmp/wt/lc',
      checkpointData: { phase: 'claimed' },
    });

    // Phase 2: heartbeats during development
    const hb1Id = ctx.traceLog.record({
      actor: performerId, action: 'heartbeat', target: taskId,
      detail: { progress: 25 }, result: 'pending',
      parentTraceId: claimTraceId,
    });
    const hb2Id = ctx.traceLog.record({
      actor: performerId, action: 'heartbeat', target: taskId,
      detail: { progress: 75 }, result: 'pending',
      parentTraceId: hb1Id,
    });
    await ctx.sessionResume.saveCheckpoint({
      performerId, currentTaskId: taskId,
      checkpointData: { phase: 'in_progress', progress: 75 },
    });

    // Phase 3: complete
    ctx.traceLog.record({
      actor: performerId, action: 'complete', target: taskId,
      detail: {
        diffSummary: '5 files changed',
        testsPassed: 20,
        commitHash: 'deadbeef',
      }, result: 'success',
      parentTraceId: hb2Id,
    });
    await ctx.sessionResume.saveCheckpoint({
      performerId,
      checkpointData: { phase: 'completed' },
    });

    // Verify full trace chain
    const chain = ctx.traceLog.getChain(claimTraceId);
    expect(chain).toHaveLength(4);
    expect(chain.map((e) => e.action)).toEqual([
      'claim', 'heartbeat', 'heartbeat', 'complete',
    ]);

    // Verify last checkpoint has no task (task was completed)
    const finalState = await ctx.sessionResume.loadCheckpoint(performerId);
    expect(finalState!.checkpointData).toEqual({ phase: 'completed' });

    // Verify task traces query
    const taskTraces = ctx.traceLog.getTaskTrace(taskId);
    expect(taskTraces).toHaveLength(4);

    // Verify performer traces query
    const performerTraces = ctx.traceLog.getPerformerTrace(performerId);
    expect(performerTraces).toHaveLength(4);
  });
});
