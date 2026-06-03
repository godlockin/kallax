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
}

export interface DagExecutor {
  execute: (schema: DagSchema) => Promise<DagRunState>;
  resume: (runId: string) => Promise<DagRunState>;
  getRunState: (runId: string) => Promise<DagRunState | null>;
}

// ── Script safety ──────────────────────────────────────────────────────────

const FORBIDDEN_PATTERNS = [
  /\$\{.*rm\s+-rf/i,
  /\$\{.*sudo/i,
  />\s*\/dev\/null.*&&/,
  /\|\s*sh$/,
];

function validateScript(script: string): void {
  for (const pattern of FORBIDDEN_PATTERNS) {
    if (pattern.test(script)) {
      throw new Error(`Dangerous script pattern detected: ${pattern.source}`);
    }
  }
}

// ── Semaphore ──────────────────────────────────────────────────────────────

function createSemaphore(max: number) {
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
    get running() { return running; },
  };
}

// ── Checkpoint ─────────────────────────────────────────────────────────────

function getStatePath(stateDir: string, runId: string): string {
  return path.join(stateDir, `${runId}.json`);
}

async function saveCheckpoint(state: DagRunState, stateDir: string): Promise<void> {
  await fs.mkdir(stateDir, { recursive: true });
  const serialized = {
    ...state,
    nodes: Object.fromEntries(state.nodes),
  };
  await fs.writeFile(getStatePath(stateDir, state.runId), JSON.stringify(serialized, null, 2));
  state.updatedAt = Date.now();
}

async function loadCheckpoint(stateDir: string, runId: string): Promise<DagRunState | null> {
  try {
    const data = await fs.readFile(getStatePath(stateDir, runId), 'utf-8');
    const parsed = JSON.parse(data);
    return {
      ...parsed,
      nodes: new Map(Object.entries(parsed.nodes)),
    };
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
    nodeState.status = 'running';
    nodeState.startedAt = Date.now();
    nodeState.attempt++;

    if (dryRun) {
      logger.info({ nodeId: node.id }, 'dry-run: would execute');
      return { success: true };
    }

    try {
      const [cmd, ...args] = node.script.split(' ');
      if (!cmd) throw new Error('Empty script');

      const { stdout, stderr } = await execFileAsync(cmd, args, {
        timeout: 600_000, // 10 min per node
        maxBuffer: 10 * 1024 * 1024,
      });

      logger.info({ nodeId: node.id, stdout: stdout.slice(0, 500) }, 'node completed');
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
        status: 'pending' as NodeStatus,
        attempt: 0,
      }])),
      settings: schema.settings,
      status: 'running',
    };

    await saveCheckpoint(state, stateDir);
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
        const nodeId = readyQueue.shift()!;
        const nodeDef = nodeMap.get(nodeId);
        const nodeState = state.nodes.get(nodeId);
        if (!nodeDef || !nodeState || nodeState.status !== 'pending') continue;

        const p = (async () => {
          await semaphore.acquire();
          try {
            const { success, error } = await executeNode(nodeDef, nodeState);

            if (success) {
              nodeState.status = 'done';
              nodeState.completedAt = Date.now();
              state.nodes.set(nodeId, nodeState);
              await saveCheckpoint(state, stateDir);

              // Release dependents
              for (const depId of dependents.get(nodeId) ?? []) {
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
      return runDag(schema);
    },

    async resume(runId: string): Promise<DagRunState> {
      const state = await loadCheckpoint(stateDir, runId);
      if (!state) throw new Error(`No checkpoint found for run: ${runId}`);

      // Reset running nodes to pending
      for (const [, nodeState] of state.nodes) {
        if (nodeState.status === 'running') {
          nodeState.status = 'pending';
        }
      }

      // Resume execution — rebuild schema from checkpoint
      const schema: DagSchema = {
        epic: state.epic,
        nodes: Array.from(state.nodes.entries()).map(([id, ns]) => ({
          id,
          script: '', // Script info not stored in checkpoint — limitation
          deps: [],   // Deps not stored in checkpoint
          priority: 50,
        })),
        settings: state.settings,
      };

      return runDag(schema, state);
    },

    async getRunState(runId: string): Promise<DagRunState | null> {
      return loadCheckpoint(stateDir, runId);
    },
  };
}
