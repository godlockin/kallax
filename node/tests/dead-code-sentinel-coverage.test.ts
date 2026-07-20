/**
 * KALLAX Dead-Module Sentinel Coverage — Phase B (EPIC-132)
 *
 * 主公 2026-07-20 命令 "直接 Phase B 开干": 把 sentinel 抓到的 29 dead modules
 * 全部加 test import, 让 sentinel coverage 从 29/151 → 0/151。
 *
 * 治根: 每个未被引用 module 现在都有 sentinel "走一遍" — type-only import +
 * typeof check, 强制 module 至少被加载 + export 可访问。
 *
 * 不删 source, 不 reduce surface — 主公 plan 明确"恢复 import, 不删"
 *
 * 分 4 个 describe by domain (便于失败时定位):
 *   A. core/* 子模块 (context / data-adapter / recommender / brief-inference / dispatch-dashboard)
 *   B. core/sqlite/* (SQLite ops + types + sync-client)
 *   C. core/master-verify/* + bridge (验证 helper / constants / bridge)
 *   D. 杂 module (redis-pubsub / dag-visualizer / schema-validator / expert-invocations-queue / master-verify-bridge)
 */
import { describe, expect, it } from 'vitest';

describe('Sentinel A — core/* domain modules', () => {
  it('context/archiver loads', async () => {
    const m = await import('../src/core/context/archiver.js');
    expect(m).toBeDefined();
  });

  it('context/auto-compressor loads', async () => {
    const m = await import('../src/core/context/auto-compressor.js');
    expect(typeof m.createAutoCompressor).toBe('function');
  });

  it('context/budget-manager loads', async () => {
    const m = await import('../src/core/context/budget-manager.js');
    expect(m).toBeDefined();
  });

  it('context/extractor loads', async () => {
    const m = await import('../src/core/context/extractor.js');
    expect(typeof m.createContextExtractor).toBe('function');
  });

  it('context/restore loads', async () => {
    const m = await import('../src/core/context/restore.js');
    expect(typeof m.createContextRestore).toBe('function');
  });

  it('data-adapter/helpers loads', async () => {
    const m = await import('../src/core/data-adapter/helpers.js');
    expect(typeof m.createDataError).toBe('function');
    expect(typeof m.readDirSafe).toBe('function');
  });

  it('data-adapter/file-adapter loads', async () => {
    const m = await import('../src/core/data-adapter/file-adapter.js');
    expect(m.FileDataAdapter).toBeDefined();
  });

  it('data-adapter/sqlite-adapter loads', async () => {
    const m = await import('../src/core/data-adapter/sqlite-adapter.js');
    expect(m.SQLiteDataAdapter).toBeDefined();
  });

  it('data-adapter/types loads', async () => {
    const m = await import('../src/core/data-adapter/types.js');
    expect(m).toBeDefined();
  });

  it('recommender/matcher loads', async () => {
    const m = await import('../src/core/recommender/matcher.js');
    expect(m).toBeDefined();
  });

  it('recommender/scorer loads', async () => {
    const m = await import('../src/core/recommender/scorer.js');
    expect(typeof m.computeTF).toBe('function');
    expect(typeof m.computeIDF).toBe('function');
    expect(typeof m.applyIDF).toBe('function');
  });

  it('brief-inference/types loads', async () => {
    const m = await import('../src/core/brief-inference/types.js');
    expect(m.BRIEF_SECTION_COUNT).toBe(4);
    expect(typeof m.BRIEF_PREFIX).toBe('string');
  });

  it('brief-inference/claim-gate loads', async () => {
    const m = await import('../src/core/brief-inference/claim-gate.js');
    expect(typeof m.enforceClaimWithBrief).toBe('function');
  });

  it('brief-inference/quality loads', async () => {
    const m = await import('../src/core/brief-inference/quality.js');
    expect(typeof m.evaluateBriefQuality).toBe('function');
  });

  it('brief-inference/assignment loads', async () => {
    const m = await import('../src/core/brief-inference/assignment.js');
    expect(m.BRIEF_INFERENCE_FIELD).toBe('brief_inference');
    expect(typeof m.combinedExpertAssignment).toBe('function');
  });

  it('dispatch-dashboard loads', async () => {
    const m = await import('../src/core/dispatch-dashboard.js');
    expect(m.KpiThresholds).toBeDefined();
  });
});

describe('Sentinel B — core/sqlite/* operations', () => {
  it('sqlite/sync-client loads', async () => {
    const m = await import('../src/core/sqlite/sync-client.js');
    expect(typeof m.createSQLiteManager).toBe('function');
  });

  it('sqlite/types loads', async () => {
    const m = await import('../src/core/sqlite/types.js');
    expect(m).toBeDefined();
  });

  it('sqlite/task-ops loads', async () => {
    const m = await import('../src/core/sqlite/task-ops.js');
    expect(typeof m.createTaskOperations).toBe('function');
  });

  it('sqlite/trace-ops loads', async () => {
    const m = await import('../src/core/sqlite/trace-ops.js');
    expect(m).toBeDefined();
  });

  it('sqlite/instance-message-ops loads', async () => {
    const m = await import('../src/core/sqlite/instance-message-ops.js');
    expect(m).toBeDefined();
  });

  it('sqlite/ticket-ops loads', async () => {
    const m = await import('../src/core/sqlite/ticket-ops.js');
    expect(m).toBeDefined();
  });
});

describe('Sentinel C — master-verify family', () => {
  it('master-verify/helpers loads', async () => {
    const m = await import('../src/core/master-verify/helpers.js');
    expect(typeof m.die).toBe('function');
    expect(typeof m.runGit).toBe('function');
  });

  it('master-verify/constants loads', async () => {
    const m = await import('../src/core/master-verify/constants.js');
    expect(m.KALLAX_ROOT).toBeDefined();
    expect(typeof m.NET_VALUE_BASELINE_V124).toBe('number');
    expect(typeof m.NET_VALUE_TARGET).toBe('number');
  });

  it('master-verify-bridge loads', async () => {
    const m = await import('../src/core/master-verify-bridge.js');
    expect(m).toBeDefined();
  });
});

describe('Sentinel D — misc top-level modules', () => {
  it('redis-pubsub loads', async () => {
    const m = await import('../src/core/redis-pubsub.js');
    expect(m).toBeDefined();
  });

  it('dag-visualizer loads', async () => {
    const m = await import('../src/core/dag-visualizer.js');
    expect(typeof m.renderDagTree).toBe('function');
  });

  it('schema-validator loads', async () => {
    const m = await import('../src/core/schema-validator.js');
    expect(m.SCHEMA_VERSION).toBe('1.0.0');
    expect(m.PhaseStatus).toBeDefined();
  });

  it('expert-invocations-queue/redis-backend loads', async () => {
    const m = await import('../src/core/expert-invocations-queue/redis-backend.js');
    expect(typeof m.createRedisBackend).toBe('function');
  });
});
