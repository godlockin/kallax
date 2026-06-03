/**
 * KALLAX DAG Generator
 * Generates executable DAG YAML from ticket dependency relationships.
 */

import type { KallaxResult } from '../types/index.js';
import type { SQLiteManager, TaskFilter } from './sqlite-manager.js';

export interface DagNodeDef {
  readonly id: string;
  readonly script: string;
  readonly deps: string[];
  readonly priority?: number;
  readonly retry?: number;
  readonly description?: string;
}

export interface DagSchema {
  readonly epic: string;
  readonly nodes: DagNodeDef[];
  readonly settings: {
    readonly max_parallel: number;
    readonly retry_count: number;
    readonly timeout_seconds: number;
    readonly on_failure: 'stop' | 'continue' | 'rollback';
  };
}

/**
 * Generate DAG YAML from tickets in the database.
 * Each ticket becomes a node with dependencies from ticket metadata.
 */
export function generateDagYaml(
  tickets: Array<{ id: string; title: string; priority: string; fileScope?: string[] }>,
  epicId: string,
): string {
  const nodes: DagNodeDef[] = tickets.map((t) => ({
    id: t.id,
    script: `kallax task claim --ticket ${t.id} && kallax task complete --ticket ${t.id}`,
    deps: [], // Will be filled from ticket dependency metadata
    priority: priorityToNumber(t.priority),
    retry: t.priority === 'P0' ? 3 : 2,
    description: t.title,
  }));

  const schema: DagSchema = {
    epic: epicId,
    nodes,
    settings: {
      max_parallel: 3,
      retry_count: 2,
      timeout_seconds: 3600,
      on_failure: 'stop',
    },
  };

  return dagSchemaToYaml(schema);
}

function priorityToNumber(p: string): number {
  switch (p) {
    case 'P0': return 90;
    case 'P1': return 70;
    case 'P2': return 50;
    default: return 30;
  }
}

/**
 * Convert DAG schema to YAML string.
 */
function dagSchemaToYaml(schema: DagSchema): string {
  const lines: string[] = [
    `# KALLAX DAG — ${schema.epic}`,
    `# Generated: ${new Date().toISOString()}`,
    '',
    `version: "1.0"`,
    `epic: "${schema.epic}"`,
    '',
    'settings:',
    `  max_parallel: ${schema.settings.max_parallel}`,
    `  retry_count: ${schema.settings.retry_count}`,
    `  timeout_seconds: ${schema.settings.timeout_seconds}`,
    `  on_failure: ${schema.settings.on_failure}`,
    '',
    'nodes:',
  ];

  for (const node of schema.nodes) {
    lines.push(`  - id: "${node.id}"`);
    lines.push(`    script: "${node.script}"`);
    if (node.deps.length > 0) {
      lines.push(`    deps: [${node.deps.map((d) => `"${d}"`).join(', ')}]`);
    }
    if (node.priority !== undefined) lines.push(`    priority: ${node.priority}`);
    if (node.retry !== undefined) lines.push(`    retry: ${node.retry}`);
    if (node.description) lines.push(`    description: "${node.description}"`);
  }

  return lines.join('\n') + '\n';
}

/**
 * Kahn's topological sort algorithm.
 * Returns tasks in dependency-respecting order.
 */
export function topologicalSort(nodes: DagNodeDef[]): DagNodeDef[] {
  const inDegree = new Map<string, number>();
  const adjacency = new Map<string, string[]>();

  for (const node of nodes) {
    inDegree.set(node.id, node.deps.length);
    for (const dep of node.deps) {
      const list = adjacency.get(dep) ?? [];
      list.push(node.id);
      adjacency.set(dep, list);
    }
  }

  const queue: string[] = [];
  for (const [id, degree] of inDegree) {
    if (degree === 0) queue.push(id);
  }

  const sorted: DagNodeDef[] = [];
  const nodeMap = new Map(nodes.map((n) => [n.id, n]));

  while (queue.length > 0) {
    const current = queue.shift()!;
    const node = nodeMap.get(current);
    if (node) sorted.push(node);

    for (const neighbor of adjacency.get(current) ?? []) {
      const newDegree = (inDegree.get(neighbor) ?? 1) - 1;
      inDegree.set(neighbor, newDegree);
      if (newDegree === 0) queue.push(neighbor);
    }
  }

  if (sorted.length !== nodes.length) {
    throw new Error('Cycle detected in DAG — cannot topological sort');
  }

  return sorted;
}
