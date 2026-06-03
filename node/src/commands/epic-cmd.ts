/**
 * KALLAX Epic Command Registration
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

export function registerEpicCommands(program: Command, ctx: AppContext): void {
  const epic = program.command('epic').description('EPIC management');

  epic
    .command('create <epicId> <title>')
    .description('Create a new EPIC')
    .action((epicId: string, title: string) => {
      try {
        const now = Date.now();
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
    .action((epicId: string) => {
      try {
        // Collect tickets for this epic
        const ticketsResult = ctx.db.listTickets({}); const tickets = ticketsResult.isOk() ? ticketsResult.value : [];
        const epicTickets = tickets.filter((t: { labels?: string[] }) => t.labels?.includes(epicId));

        if (epicTickets.length === 0) {
          logger.warn({ epicId }, 'No tickets found for epic');
          process.exit(0);
        }

        // Calculate metrics
        const depsMap = new Map<string, string[]>();
        const scopes: string[][] = [];
        let maxBlocked = 0;

        for (const t of epicTickets) {
          depsMap.set(t.id, []); // Simplified — real deps would come from ticket metadata
          if (t.fileScope) scopes.push(t.fileScope);
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
    .action((epicId: string) => {
      try {
        const ticketsResult = ctx.db.listTickets({}); const tickets = ticketsResult.isOk() ? ticketsResult.value : []
          .filter((t: { labels?: string[] }) => t.labels?.includes(epicId));

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

  epic
    .command('run <epicId>')
    .description('Execute EPIC in DAG mode')
    .option('--dry-run', 'Simulate without executing')
    .action(async (epicId: string, opts?: { dryRun?: boolean }) => {
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
          if (line.match(/^\s*- id:/)) {
            const id = (line.match(/"([^"]+)"/) ?? [])[1] ?? '';
            nodes.push({ id, script: '', deps: [] });
          } else if (line.match(/^\s*script:/) && nodes.length > 0) {
            nodes[nodes.length - 1]!.script = (line.match(/"([^"]+)"/) ?? [])[1] ?? '';
          } else if (line.match(/^\s*deps:/) && nodes.length > 0) {
            const depsStr = (line.match(/\[(.*)\]/) ?? [])[1] ?? '';
            nodes[nodes.length - 1]!.deps = depsStr.split(',').map((s: string) => s.trim().replace(/"/g, '')).filter(Boolean);
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
