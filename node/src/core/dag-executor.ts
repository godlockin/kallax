/**
 * KALLAX DAG Executor
 * Kahn wave-based parallel execution with semaphore, retry, and checkpoint.
 */

import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import * as fs from 'node:fs/promises';
import * as path from 'node:path';
import type { DagNodeDef, DagSchema } from './dag-generator.js';
import { topologicalSort } from './dag-generator.js';
import { logger } from '../utils/logger.js';

const execFileAsync = promisify(execFile);

// ── Types ──────────────────────────────────────────────────────────────────

export type NodeStatus = 'pending' | 'running' | 'done' | 'failed' | 'skipped';

export interface DagRunState {
  readonly runId: string;
  readonly epic: string;
  readonly startedAt: number;
  updatedAt: number;
  readonly nodes: Map<string, NodeState>;
  readonly settings: DagSchema['settings'];
  status: 'running' | 'completed' | 'failed';
}

interface NodeState {
  id: string;
  status: NodeStatus;
  attempt: number;
  error?: string;
  startedAt?: number;
  completedAt?: number;
}

export interface DagExecutorOptions {
  readonly maxParallel?: number;
  readonly stateDir?: string;
  readonly dryRun?: boolean;
  readonly maxWorktrees?: number;
}

export interface DagExecutor {
  execute: (schema: DagSchema) => Promise<DagRunState>;
  resume: (runId: string) => Promise<DagRunState>;
  getRunState: (runId: string) => Promise<DagRunState | null>;
}

// ── Limits ────────────────────────────────────────────────────────────────────

const MAX_NODES = 1000;

// ── Script safety ──────────────────────────────────────────────────────────

const ALLOWED_COMMANDS = new Set([
  'kallax', 'git', 'npm', 'npx', 'node', 'tsx',
  'cargo', 'rustc', 'make', 'echo', 'ls', 'cat',
  'grep', 'find', 'mkdir', 'cp', 'mv', 'rm',
  'python3', 'bash', 'sh',
]);

function validateScript(script: string): void {
  const cmd = script.trim().split(/\s+/)[0];
  if (cmd == null || !ALLOWED_COMMANDS.has(cmd)) {
    throw new Error(`Command not in allowlist: ${cmd ?? '<empty>'}`);
  }
}

async function checkWorktreeLimit(limit: number): Promise<void> {
  try {
    const { stdout } = await execFileAsync('git', ['worktree', 'list'], { timeout: 5000 });
    const count = stdout.trim().split('\n').filter(Boolean).length;
    if (count >= limit) {
      throw new Error(`Worktree count ${String(count)} exceeds limit of ${String(limit)}`);
    }
  } catch (error: unknown) {
    if (error instanceof Error && error.message.startsWith('Worktree count')) {
      throw error;
    }
    // Not a git repo or git unavailable — skip check
  }
}

// ── Semaphore ──────────────────────────────────────────────────────────────

function createSemaphore(max: number): { acquire(): Promise<void>; release(): void; readonly running: number } {
  let running = 0;
  const queue: Array<() => void> = [];

  return {
    async acquire(): Promise<void> {
      if (running < max) { running++; return; }
      return new Promise<void>((resolve) => {
        queue.push(() => { running++; resolve(); });
      });
    },
    release(): void {
      running--;
      const next = queue.shift();
      if (next) next();
    },
    get running(): number { return running; },
  };
}

// ── Checkpoint ─────────────────────────────────────────────────────────────

function getStatePath(stateDir: string, runId: string): string {
  return path.join(stateDir, `${runId}.json`);
}

async function saveCheckpoint(state: DagRunState, stateDir: string, schema?: DagSchema): Promise<void> {
  await fs.mkdir(stateDir, { recursive: true });
  const serialized: Record<string, unknown> = {
    ...state,
    nodes: Object.fromEntries(state.nodes),
  };
  if (schema) {
    serialized['schema'] = schema;
  }
  await fs.writeFile(getStatePath(stateDir, state.runId), JSON.stringify(serialized, null, 2));
  state.updatedAt = Date.now();
}

async function loadCheckpoint(stateDir: string, runId: string): Promise<DagRunState | null> {
  try {
    const data = await fs.readFile(getStatePath(stateDir, runId), 'utf-8');
    const parsed = JSON.parse(data) as unknown as Record<string, unknown>;
    const nodesRecord = parsed['nodes'] as Record<string, NodeState>;
    return {
      runId: typeof parsed['runId'] === 'string' ? parsed['runId'] : '',
      epic: typeof parsed['epic'] === 'string' ? parsed['epic'] : '',
      startedAt: typeof parsed['startedAt'] === 'number' ? parsed['startedAt'] : 0,
      updatedAt: typeof parsed['updatedAt'] === 'number' ? parsed['updatedAt'] : 0,
      status: (parsed['status'] as DagRunState['status']) ?? 'running',
      settings: parsed['settings'] as DagRunState['settings'],
      nodes: new Map(Object.entries(nodesRecord)),
    } as DagRunState;
  } catch {
    return null;
  }
}

// ── Main Export ────────────────────────────────────────────────────────────

export function createDagExecutor(options: DagExecutorOptions = {}): DagExecutor {
  const { maxParallel = 3, stateDir = '.kallax/dag-runs', dryRun = false } = options;

  async function executeNode(
    node: DagNodeDef,
    nodeState: NodeState,
  ): Promise<{ success: boolean; error?: string }> {
    validateScript(node.script);

    const worktreeLimit = options.maxWorktrees;
    if (worktreeLimit !== undefined && worktreeLimit > 0) {
      await checkWorktreeLimit(worktreeLimit);
    }

    nodeState.status = 'running';
    nodeState.startedAt = Date.now();
    nodeState.attempt++;

    if (dryRun) {
      logger.info({ nodeId: node.id }, 'dry-run: would execute');
      return { success: true };
    }

    try {
      const [cmd, ...args] = node.script.split(' ');
      if (cmd == null || cmd === '') throw new Error('Empty script');

      const { stdout: _stdout } = await execFileAsync(cmd, args, {
        timeout: 600_000, // 10 min per node
        maxBuffer: 10 * 1024 * 1024,
      });

      logger.info({ nodeId: node.id, stdout: _stdout.slice(0, 500) }, 'node completed');
      return { success: true };
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : String(error);
      logger.error({ nodeId: node.id, error: message }, 'node failed');
      return { success: false, error: message };
    }
  }

  async function runDag(schema: DagSchema, existingState?: DagRunState): Promise<DagRunState> {
    const sorted = topologicalSort(schema.nodes);
    const nodeMap = new Map(sorted.map((n) => [n.id, n]));

    const state: DagRunState = existingState ?? {
      runId: `dag_${Date.now().toString(36)}`,
      epic: schema.epic,
      startedAt: Date.now(),
      updatedAt: Date.now(),
      nodes: new Map(sorted.map((n) => [n.id, {
        id: n.id,
        status: 'pending',
        attempt: 0,
      }])),
      settings: schema.settings,
      status: 'running',
    };

    await saveCheckpoint(state, stateDir, schema);
    logger.info({ runId: state.runId, nodeCount: sorted.length }, 'DAG execution started');

    // Build dependency graph
    const inDegree = new Map<string, number>();
    const dependents = new Map<string, string[]>();
    for (const node of sorted) {
      inDegree.set(node.id, node.deps.length);
      for (const dep of node.deps) {
        const list = dependents.get(dep) ?? [];
        list.push(node.id);
        dependents.set(dep, list);
      }
    }

    // Find initial ready nodes
    const readyQueue: string[] = [];
    for (const [id, degree] of inDegree) {
      if (degree === 0 && state.nodes.get(id)?.status === 'pending') {
        readyQueue.push(id);
      }
    }

    const semaphore = createSemaphore(maxParallel);
    let hasFailure = false;

    // Wave execution loop
    while (readyQueue.length > 0 || semaphore.running > 0) {
      // Process ready nodes in parallel waves
      const wave: Promise<void>[] = [];

      while (readyQueue.length > 0 && semaphore.running < maxParallel) {
        const nodeId = readyQueue.shift() ?? '';
        const nodeDef = nodeMap.get(nodeId);
        const nodeState = state.nodes.get(nodeId);
        if (nodeId === '' || !nodeDef || nodeState?.status !== 'pending') continue;

        const p = (async (): Promise<void> => {
          await semaphore.acquire();
          try {
            const { success, error } = await executeNode(nodeDef, nodeState);

            if (success) {
              nodeState.status = 'done';
              nodeState.completedAt = Date.now();
              state.nodes.set(nodeId, nodeState);
              await saveCheckpoint(state, stateDir);

              // Dependents may be undefined — suppress prefer-optional-chain (map not applicable in for-of)
              // eslint-disable-next-line @typescript-eslint/prefer-optional-chain
              for (const depId of (dependents.get(nodeId) ?? [])) {
                const newDegree = (inDegree.get(depId) ?? 1) - 1;
                inDegree.set(depId, newDegree);
                if (newDegree === 0) {
                  const depState = state.nodes.get(depId);
                  if (depState?.status === 'pending') {
                    readyQueue.push(depId);
                  }
                }
              }
            } else {
              nodeState.status = 'failed';
              nodeState.error = error;
              state.nodes.set(nodeId, nodeState);
              await saveCheckpoint(state, stateDir);

              if (state.settings.on_failure === 'stop') {
                hasFailure = true;
              } else if (state.settings.on_failure === 'continue') {
                nodeState.status = 'skipped';
              }
            }
          } finally {
            semaphore.release();
          }
        })();
        wave.push(p);
      }

      if (wave.length === 0 && semaphore.running === 0) break;
      await Promise.all(wave);
    }

    // hasFailure mutated in async closure — linter can't track
    // eslint-disable-next-line @typescript-eslint/no-unnecessary-condition
    state.status = hasFailure ? 'failed' : 'completed';
    await saveCheckpoint(state, stateDir);

    const completed = Array.from(state.nodes.values()).filter((n) => n.status === 'done').length;
    logger.info(
      { runId: state.runId, completed, total: sorted.length, status: state.status },
      'DAG execution finished',
    );

    return state;
  }

  return {
    async execute(schema: DagSchema): Promise<DagRunState> {
      if (schema.nodes.length > MAX_NODES) {
        throw new Error(`DAG exceeds maximum of ${String(MAX_NODES)} nodes (got ${String(schema.nodes.length)})`);
      }
      return runDag(schema);
    },

    async resume(runId: string): Promise<DagRunState> {
      const raw = JSON.parse(await fs.readFile(getStatePath(stateDir, runId), 'utf-8')) as unknown as Record<string, unknown>;
      const nodesRecord = raw['nodes'] as Record<string, NodeState>;
      const state: DagRunState = {
        runId: typeof raw['runId'] === 'string' ? raw['runId'] : '',
        epic: typeof raw['epic'] === 'string' ? raw['epic'] : '',
        startedAt: typeof raw['startedAt'] === 'number' ? raw['startedAt'] : 0,
        updatedAt: typeof raw['updatedAt'] === 'number' ? raw['updatedAt'] : 0,
        status: (raw['status'] as DagRunState['status']) ?? 'running',
        settings: raw['settings'] as DagRunState['settings'],
        nodes: new Map(Object.entries(nodesRecord)),
      };
      const storedSchema = raw['schema'] as DagSchema | undefined;
      if (!storedSchema) {
        throw new Error(`Cannot resume ${runId}: checkpoint has no schema, start a fresh run`);
      }

      // Reset running nodes to pending
      for (const [, nodeState] of state.nodes) {
        if (nodeState.status === 'running') {
          nodeState.status = 'pending';
        }
      }

      return runDag(storedSchema, state);
    },

    async getRunState(runId: string): Promise<DagRunState | null> {
      return loadCheckpoint(stateDir, runId);
    },
  };
}
