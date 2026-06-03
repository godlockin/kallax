/**
 * DAG Executor tests: single node, dependency chain, dry-run, failure + stop.
 */

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { mkdir, rm } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { randomUUID } from 'node:crypto';
import { createDagExecutor } from '../src/core/dag-executor.js';
import type { DagSchema } from '../src/core/dag-generator.js';

const settings: DagSchema['settings'] = {
  max_parallel: 3, retry_count: 2, timeout_seconds: 60, on_failure: 'stop',
};

describe('DagExecutor', () => {
  let tmpDir: string;

  beforeEach(async () => {
    tmpDir = join(tmpdir(), `kallax-dag-${randomUUID()}`);
    await mkdir(tmpDir, { recursive: true });
  });

  afterEach(async () => {
    await rm(tmpDir, { recursive: true, force: true });
  });

  it('executes single-node DAG in dry-run', async () => {
    const dag = createDagExecutor({ dryRun: true, stateDir: tmpDir });
    const r = await dag.execute({
      epic: 'test', nodes: [{ id: 'a', script: 'echo x', deps: [] }], settings,
    });
    expect(r.status).toBe('completed');
    expect(r.nodes.get('a')?.status).toBe('done');
  });

  it('executes dependency chain in topological order', async () => {
    const dag = createDagExecutor({ dryRun: true, stateDir: tmpDir });
    const r = await dag.execute({
      epic: 'test',
      nodes: [
        { id: 'a', script: 'echo a', deps: [] },
        { id: 'b', script: 'echo b', deps: ['a'] },
        { id: 'c', script: 'echo c', deps: ['b'] },
      ],
      settings,
    });
    expect(r.status).toBe('completed');
    const done = Array.from(r.nodes.values()).filter((n) => n.status === 'done');
    expect(done).toHaveLength(3);
  });

  it('dry-run skips actual command execution', async () => {
    // A script that would fail at runtime is skipped entirely in dry-run
    const dag = createDagExecutor({ dryRun: true, stateDir: tmpDir });
    const r = await dag.execute({
      epic: 'test', nodes: [{ id: 'a', script: 'node -e process.exit(1)', deps: [] }], settings,
    });
    expect(r.status).toBe('completed');
    expect(r.nodes.get('a')?.status).toBe('done');
  });

  it('marks DAG as failed on node error with on_failure=stop', async () => {
    const dag = createDagExecutor({ dryRun: false, stateDir: tmpDir });
    const r = await dag.execute({
      epic: 'test',
      nodes: [
        { id: 'setup', script: 'node -e console.log(0)', deps: [] },
        { id: 'fail', script: 'node -e process.exit(42)', deps: ['setup'] },
      ],
      settings,
    });
    expect(r.status).toBe('failed');
    expect(r.nodes.get('setup')?.status).toBe('done');
    expect(r.nodes.get('fail')?.status).toBe('failed');
    expect(r.nodes.get('fail')?.error).toBeDefined();
  });
});
