/**
 * KALLAX Ticket Command Registration
 */

import { Command } from 'commander';
import type { AppContext } from '../cli-context.js';
import { logger } from '../utils/logger.js';
import { KallaxError } from '../types/index.js';

export function registerTicketCommands(program: Command, ctx: AppContext): void {
  const ticketCmd = program.command('ticket').description('Ticket management');

  ticketCmd
    .command('create <title>')
    .description('Create a new ticket')
    .option('-d, --description <desc>', 'Ticket description', '')
    .option('-p, --priority <priority>', 'Priority (P0/P1/P2/P3)', 'P2')
    .option('-s, --scope <files>', 'File scope (comma-separated)', '')
    .action((title: string, opts?: { description?: string; priority?: string; scope?: string }) => {
      try {
        const now = Date.now();
        const id = `TICKET-${now.toString(36).toUpperCase()}`;
        const ticket = {
          id,
          title,
          description: opts?.['description'] ?? '',
          status: 'todo' as const,
          priority: (opts?.['priority'] ?? 'P2') as 'P0' | 'P1' | 'P2' | 'P3',
          assigneeId: null,
          createdAt: now,
          updatedAt: now,
          acceptanceCriteria: [],
          labels: [],
          fileScope: opts?.['scope'] ? opts['scope'].split(',').map((s: string) => s.trim()) : undefined,
        };
        const result = ctx.db.createTicket(ticket);
        if (result.isErr()) {
          logger.kallaxError(result.error);
          process.exit(1);
        }
        process.stdout.write(JSON.stringify({ id, title, status: 'created' }) + '\n');
      } catch (error: unknown) {
        logger.kallaxError(KallaxError.fromUnknown(error));
        process.exit(1);
      }
    });
}
