/**
 * KALLAX Dependency Analysis Command Registration
 */

import { Command } from 'commander';
import type { AppContext } from '../cli-context.js';
import { logger } from '../utils/logger.js';
import { KallaxError } from '../types/index.js';
import { analyzeComplexity, calculateDependencyDepth, countCrossModules } from '../core/complexity-analyzer.js';

export function registerDependencyCommands(program: Command, ctx: AppContext): void {
  program
    .command('dependency:analyze <ticketId>')
    .description('Analyze task dependency relationships')
    .option('-d, --depth <depth>', 'Max dependency depth', '10')
    .action((ticketId: string, opts?: { depth?: string }) => {
      try {
        const ticketsResult = ctx.db.listTickets({});
        const tickets = ticketsResult.isOk() ? ticketsResult.value : [];

        // Build dependency map from ticket labels / parent references
        const depsMap = new Map<string, string[]>();
        const targetTicket = tickets.find((t: { id: string }) => t.id === ticketId);
        if (!targetTicket) {
          logger.error({ ticketId }, 'ticket not found');
          process.exit(1);
        }

        for (const t of tickets) {
          const deps: string[] = [];
          // Look for parent relationships or label-based deps
          if (t.parentTicketId) deps.push(t.parentTicketId);
          depsMap.set(t.id, deps);
        }

        const maxDepth = parseInt(opts?.['depth'] ?? '10', 10);
        const depDepth = calculateDependencyDepth(depsMap);
        const crossModule = countCrossModules(tickets.map((t: { fileScope?: string[] }) => t.fileScope ?? []));

        const result = analyzeComplexity({
          subtaskCount: tickets.length,
          dependencyDepth: Math.min(depDepth, maxDepth),
          maxBlockedBy: 0,
          crossModuleCount: crossModule,
        });

        process.stdout.write(JSON.stringify({
          ticketId, totalTickets: tickets.length, dependencyDepth: depDepth,
          crossModule, complexity: result,
        }, null, 2) + '\n');
      } catch (error: unknown) {
        logger.kallaxError(KallaxError.fromUnknown(error));
        process.exit(1);
      }
    });
}
