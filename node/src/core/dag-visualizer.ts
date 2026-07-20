/**
 * KALLAX DAG Visualizer
 * ASCII tree and status display for DAG execution.
 */

import type { DagNodeDef } from './dag-generator.js';

export type NodeDisplayStatus = 'pending' | 'running' | 'done' | 'failed' | 'skipped';

const STATUS_ICONS: Record<NodeDisplayStatus, string> = {
  pending: '○',
  running: '●',
  done: '✓',
  failed: '✗',
  skipped: '⊘',
};

export interface DisplayNode {
  id: string;
  status: NodeDisplayStatus;
  description?: string;
  children: DisplayNode[];
}

/**
 * Build a tree structure from DAG nodes for visualization.
 */
function buildTree(nodes: DagNodeDef[], statuses?: Map<string, NodeDisplayStatus>): DisplayNode[] {
  const children = new Map<string, DisplayNode[]>();
  const roots: DagNodeDef[] = [];

  for (const node of nodes) {
    if (node.deps.length === 0) {
      roots.push(node);
    }
    for (const dep of node.deps) {
      const list = children.get(dep) ?? [];
      const displayNode = statuses
        ? { id: node.id, status: statuses.get(node.id) ?? 'pending', children: [] }
        : { id: node.id, status: 'pending' as NodeDisplayStatus, children: [] };
      list.push(displayNode);
      children.set(dep, list);
    }
  }

  return roots.map((r) => ({
    id: r.id,
    status: statuses?.get(r.id) ?? 'pending',
    description: r.description,
    children: children.get(r.id) ?? [],
  }));
}

/**
 * Render ASCII tree of the DAG.
 */
export function renderDagTree(
  nodes: DagNodeDef[],
  statuses?: Map<string, NodeDisplayStatus>,
): string {
  const roots = buildTree(nodes, statuses);
  const lines: string[] = [];

  function renderNode(node: DisplayNode, prefix: string, isLast: boolean): void {
    const icon = STATUS_ICONS[node.status];
    const desc = node.description != null ? ` — ${node.description}` : '';
    const connector = isLast ? '└──' : '├──';
    lines.push(`${prefix}${connector} ${icon} ${node.id}${desc}`);

    const childPrefix = prefix + (isLast ? '    ' : '│   ');
    for (let i = 0; i < node.children.length; i++) {
      const child = node.children[i];
      if (child !== undefined) {
        renderNode(child, childPrefix, i === node.children.length - 1);
      }
    }
  }

  for (let i = 0; i < roots.length; i++) {
    const root = roots[i];
    if (root !== undefined) {
      renderNode(root, '', i === roots.length - 1);
    }
  }

  return lines.join('\n');
}

/**
 * Render summary stats for DAG execution.
 */
export function renderDagSummary(
  total: number,
  statuses: Map<string, NodeDisplayStatus>,
): string {
  const done = Array.from(statuses.values()).filter((s) => s === 'done').length;
  const running = Array.from(statuses.values()).filter((s) => s === 'running').length;
  const failed = Array.from(statuses.values()).filter((s) => s === 'failed').length;
  const pending = Array.from(statuses.values()).filter((s) => s === 'pending').length;

  const barTotal = 30;
  const doneBar = Math.round((done / total) * barTotal);
  const runningBar = Math.round((running / total) * barTotal);

  return [
    '',
    '╔══════════════════════════════════════╗',
    '║        DAG Execution Status          ║',
    '╠══════════════════════════════════════╣',
    `║  ✓ Done:     ${String(done).padEnd(20)} ║`,
    `║  ● Running:  ${String(running).padEnd(20)} ║`,
    `║  ○ Pending:  ${String(pending).padEnd(20)} ║`,
    `║  ✗ Failed:   ${String(failed).padEnd(20)} ║`,
    `║  Total:      ${String(total).padEnd(20)} ║`,
    '╠══════════════════════════════════════╣',
    `║  [${'█'.repeat(doneBar)}${'●'.repeat(runningBar)}${'·'.repeat(barTotal - doneBar - runningBar)}] ║`,
    '╚══════════════════════════════════════╝',
    '',
  ].join('\n');
}
