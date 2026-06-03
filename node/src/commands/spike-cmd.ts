/**
 * KALLAX Spike Command Registration
 */

import { Command } from 'commander';
import type { AppContext } from '../cli-context.js';
import { logger } from '../utils/logger.js';
import { KallaxError } from '../types/index.js';

export function registerSpikeCommands(program: Command, _ctx: AppContext): void {
  const spikeCmd = program.command('spike').description('Technical spike management');

  spikeCmd
    .command('create <name>')
    .description('Create a technical spike')
    .option('-g, --goal <goal>', 'Spike goal', '')
    .option('-t, --timebox <minutes>', 'Timebox in minutes', '120')
    .action(async (name: string, opts?: { goal?: string; timebox?: string }) => {
      try {
        const now = Date.now();
        const id = `SPIKE-${now.toString(36).toUpperCase()}`;
        const { getKnowledgeBase } = await import('../core/knowledge-base.js');
        const kb = getKnowledgeBase();

        const result = kb.add({
          title: `[SPIKE] ${name}`,
          content: JSON.stringify({
            id, name, goal: opts?.['goal'] ?? '',
            timebox: parseInt(opts?.['timebox'] ?? '120', 10),
            status: 'active', createdAt: now,
          }),
          tags: ['spike', 'research'],
          source: 'spike-cli',
        });

        if (result.isErr()) { logger.kallaxError(result.error); process.exit(1); }

        process.stdout.write(JSON.stringify({
          id, name, goal: opts?.['goal'] ?? '',
          timebox: parseInt(opts?.['timebox'] ?? '120', 10),
          status: 'active', knowledgeId: result.value.id,
        }) + '\n');
      } catch (error: unknown) {
        logger.kallaxError(KallaxError.fromUnknown(error));
        process.exit(1);
      }
    });

  spikeCmd
    .command('complete <name>')
    .description('Mark a technical spike as complete')
    .option('-f, --findings <findings>', 'Key findings')
    .action(async (name: string, opts?: { findings?: string }) => {
      try {
        const { getKnowledgeBase } = await import('../core/knowledge-base.js');
        const kb = getKnowledgeBase();

        const searchResult = kb.search({
          terms: name.toLowerCase().split(/\s+/).filter(Boolean),
          tags: ['spike'],
          limit: 5,
          sortBy: 'date',
        });

        if (searchResult.isErr()) { logger.kallaxError(searchResult.error); process.exit(1); }

        const active = searchResult.value.filter(
          (r) => r.entry.tags.includes('spike') && r.entry.content.includes('"active"'),
        );

        if (active.length === 0) {
          logger.error({ name }, 'no active spike found');
          process.exit(1);
        }

        const entry = active[0]!.entry;
        const existing = JSON.parse(entry.content);
        existing.status = 'completed';
        existing.completedAt = Date.now();
        existing.findings = opts?.['findings'] ?? '';

        const updateResult = kb.update(entry.id, {
          content: JSON.stringify(existing),
          tags: [...entry.tags, 'completed'],
        });

        if (updateResult.isErr()) { logger.kallaxError(updateResult.error); process.exit(1); }

        process.stdout.write(JSON.stringify({
          name, id: existing.id, status: 'completed',
          findings: opts?.['findings'] ?? '',
          elapsed: existing.completedAt - existing.createdAt,
        }) + '\n');
      } catch (error: unknown) {
        logger.kallaxError(KallaxError.fromUnknown(error));
        process.exit(1);
      }
    });
}
