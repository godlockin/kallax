/**
 * KALLAX Epic Command Registration
 *
 * EPIC-054-C: 6-state machine validation
 *   planning → active → blocked → done → archived → closed
 *   Reject state-jumps (e.g. planning → done)
 *   Allow unblock (blocked → active) and reopen (done → active, archived → done)
 *
 * State machine doc: jira/schemas/epic-state-machine.md
 * Cleanup script:    scripts/epic/cleanup-empty.sh
 * Integration test:  tests/integration/epic-state-machine-test.sh (8/8 PASS)
 */

import { Command } from 'commander';
import type { AppContext } from '../cli-context.js';
import { logger } from '../utils/logger.js';
import { KallaxError } from '../types/index.js';
import { analyzeComplexity, calculateDependencyDepth, countCrossModules } from '../core/complexity-analyzer.js';
import { generateDagYaml } from '../core/dag-generator.js';
import { createDagExecutor } from '../core/dag-executor.js';
import { renderDagTree, renderDagSummary } from '../core/dag-visualizer.js';
import * as fs from 'node:fs';

// EPIC-054-C: 6-state machine definition
export const EPIC_STATES = ['planning', 'active', 'blocked', 'done', 'archived', 'closed'] as const;
export type EpicState = typeof EPIC_STATES[number];

// Valid forward + recovery transitions
const VALID_TRANSITIONS: Readonly<Record<EpicState, ReadonlyArray<EpicState>>> = {
  planning: ['active'],
  active:   ['blocked', 'done'],
  blocked:  ['active'],           // unblock
  done:     ['archived', 'active'], // archive OR reopen
  archived: ['closed', 'done'],     // close OR restore
  closed:   [],                     // terminal — no further transitions
};

/**
 * EPIC-054-C: validate a state transition.
 * Returns null if valid, error string if invalid.
 */
export function validateTransition(from: string, to: string): string | null {
  if (!EPIC_STATES.includes(from as EpicState)) {
    return `Invalid current state: '${from}' (must be one of ${EPIC_STATES.join(', ')})`;
  }
  if (!EPIC_STATES.includes(to as EpicState)) {
    return `Invalid target state: '${to}' (must be one of ${EPIC_STATES.join(', ')})`;
  }
  const allowed = VALID_TRANSITIONS[from as EpicState];
  if (!allowed.includes(to as EpicState)) {
    return `Invalid transition: ${from} → ${to} (forbidden state-jump; allowed from ${from}: ${allowed.join(', ') || 'none (terminal)'})`;
  }
  return null;
}

export function registerEpicCommands(program: Command, ctx: AppContext): void {
  const epic = program.command('epic').description('EPIC management');

  epic
    .command('create <epicId> <title>')
    .description('Create a new EPIC')
    .action((epicId: string, title: string): void => {
      try {
        const epicData = {
          epicId, title,
          createdAt: new Date().toISOString(),
          status: 'planning',
          tickets: [] as string[],
        };
        const dir = `jira/epics/${epicId}`;
        fs.mkdirSync(dir, { recursive: true });
        fs.writeFileSync(`${dir}/epic.json`, JSON.stringify(epicData, null, 2));
        process.stdout.write(JSON.stringify(epicData, null, 2) + '\n');
      } catch (error: unknown) {
        logger.kallaxError(KallaxError.fromUnknown(error));
        process.exit(1);
      }
    });

  epic
    .command('analyze <epicId>')
    .description('Analyze EPIC complexity')
    .action((epicId: string): void => {
      try {
        // Collect tickets for this epic
        const ticketsResult = ctx.db.listTickets({}); const tickets = ticketsResult.isOk() ? ticketsResult.value : [];
        const epicTickets = tickets.filter((t: { labels?: string[] }) => t.labels?.includes(epicId) === true);

        if (epicTickets.length === 0) {
          logger.warn({ epicId }, 'No tickets found for epic');
          process.exit(0);
        }

        // Calculate metrics
        const depsMap = new Map<string, string[]>();
        const scopes: string[][] = [];
        const maxBlocked = 0;

        for (const t of epicTickets) {
          depsMap.set(t.id, []); // Simplified — real deps would come from ticket metadata
          if (t.fileScope !== undefined && t.fileScope.length > 0) scopes.push(t.fileScope);
        }

        const depDepth = calculateDependencyDepth(depsMap);
        const crossModule = countCrossModules(scopes);

        const result = analyzeComplexity({
          subtaskCount: epicTickets.length,
          dependencyDepth: depDepth,
          maxBlockedBy: maxBlocked,
          crossModuleCount: crossModule,
        });

        process.stdout.write(JSON.stringify(result, null, 2) + '\n');
      } catch (error: unknown) {
        logger.kallaxError(KallaxError.fromUnknown(error));
        process.exit(1);
      }
    });

  epic
    .command('plan <epicId>')
    .description('Generate DAG YAML for EPIC')
    .action((epicId: string): void => {
      try {
        const ticketsResult = ctx.db.listTickets({}); const tickets = ticketsResult.isOk() ? ticketsResult.value : []
          .filter((t: { labels?: string[] }) => t.labels?.includes(epicId) === true);

        const yaml = generateDagYaml(tickets, epicId);
        const dir = 'jira/epics';
        fs.mkdirSync(dir, { recursive: true });
        fs.writeFileSync(`${dir}/${epicId}-dag.yml`, yaml);
        process.stdout.write(yaml);
      } catch (error: unknown) {
        logger.kallaxError(KallaxError.fromUnknown(error));
        process.exit(1);
      }
    });

  // EPIC-054-C: status subcommand with 6-state machine validation
  epic
    .command('status <epicId> <newStatus>')
    .description('Transition EPIC to a new state (6-state machine: planning→active→blocked→done→archived→closed)')
    .action((epicId: string, newStatus: string): void => {
      try {
        if (!EPIC_STATES.includes(newStatus as EpicState)) {
          logger.error({
            event: 'epic_status_invalid_state',
            epicId,
            newStatus,
            validStates: EPIC_STATES,
          }, `Invalid state: '${newStatus}' (must be one of ${EPIC_STATES.join(', ')})`);
          process.exit(1);
        }
        const epicPath = `jira/epics/${epicId}/epic.json`;
        if (!fs.existsSync(epicPath)) {
          logger.error({ epicId, epicPath }, 'EPIC not found');
          process.exit(1);
        }
        const content = fs.readFileSync(epicPath, 'utf-8');
        const epicData = JSON.parse(content) as { status?: string };
        const currentStatus = epicData.status ?? 'planning';

        const validationError = validateTransition(currentStatus, newStatus);
        if (validationError !== null) {
          logger.error({
            event: 'epic_status_invalid_transition',
            epicId,
            from: currentStatus,
            to: newStatus,
            reason: validationError,
          }, `State transition rejected: ${validationError}`);
          process.exit(1);
        }

        // Apply transition (atomic write: tmp + rename, 跟 EPIC-041-C 原子写联动)
        const updated = { ...epicData, status: newStatus };
        const tmpPath = `${epicPath}.tmp`;
        fs.writeFileSync(tmpPath, JSON.stringify(updated, null, 2));
        fs.renameSync(tmpPath, epicPath);

        logger.info({
          event: 'epic_status_transitioned',
          epicId,
          from: currentStatus,
          to: newStatus,
          timestamp: new Date().toISOString(),
        }, `EPIC ${epicId} transitioned: ${currentStatus} → ${newStatus}`);

        process.stdout.write(JSON.stringify({
          epicId,
          from: currentStatus,
          to: newStatus,
          transitionedAt: new Date().toISOString(),
        }, null, 2) + '\n');
      } catch (error: unknown) {
        logger.kallaxError(KallaxError.fromUnknown(error));
        process.exit(1);
      }
    });

  epic
    .command('run <epicId>')
    .description('Execute EPIC in DAG mode')
    .option('--dry-run', 'Simulate without executing')
    .action(async (epicId: string, opts?: { dryRun?: boolean }): Promise<void> => {
      try {
        const dagPath = `jira/epics/${epicId}-dag.yml`;
        if (!fs.existsSync(dagPath)) {
          logger.error({ epicId }, 'DAG file not found. Run epic:plan first.');
          process.exit(1);
        }
        // Parse YAML (simple inline)
        const yamlContent = fs.readFileSync(dagPath, 'utf-8');
        logger.info({ epicId, dryRun: opts?.['dryRun'] }, 'executing EPIC via DAG');

        const executor = createDagExecutor({ dryRun: opts?.['dryRun'] });
        // Inline YAML parse — simplified for demo
        const ep = epicId;
        const nodes: Array<{ id: string; script: string; deps: string[]; priority?: number }> = [];

        for (const line of yamlContent.split('\n')) {
          if (/^\s*- id:/.exec(line) !== null) {
            const id = (/"([^"]+)"/.exec(line) ?? [])[1] ?? '';
            nodes.push({ id, script: '', deps: [] });
          } else if (/^\s*script:/.exec(line) !== null && nodes.length > 0) {
            const last = nodes[nodes.length - 1];
            if (last !== undefined) {
              last.script = (/"([^"]+)"/.exec(line) ?? [])[1] ?? '';
            }
          } else if (/^\s*deps:/.exec(line) !== null && nodes.length > 0) {
            const depsStr = (/\[(.*)\]/.exec(line) ?? [])[1] ?? '';
            const last = nodes[nodes.length - 1];
            if (last !== undefined) {
              last.deps = depsStr.split(',').map((s: string) => s.trim().replace(/"/g, '')).filter(Boolean);
            }
          }
        }

        const schema = {
          epic: ep,
          nodes,
          settings: { max_parallel: 3, retry_count: 2, timeout_seconds: 3600, on_failure: 'stop' as const },
        };

        const state = await executor.execute(schema);
        const statusMap = new Map<string, 'pending' | 'running' | 'done' | 'failed' | 'skipped'>();
        for (const [id, ns] of state.nodes) { statusMap.set(id, ns.status); }

        process.stdout.write(renderDagSummary(nodes.length, statusMap));
        process.stdout.write(renderDagTree(nodes, statusMap) + '\n');
        process.exit(state.status === 'completed' ? 0 : 1);
      } catch (error: unknown) {
        logger.kallaxError(KallaxError.fromUnknown(error));
        process.exit(1);
      }
    });
}
